# frozen_string_literal: true

# name: discourse-insightful
# about: Adds an insightful button next to the like button, allowing users to mark posts as insightful
# version: 1.0.0
# authors: Discourse Team
# url: https://github.com/narayanan79/discourse-insightful
# required_version: 3.5

enabled_site_setting :insightful_enabled

# Register stylesheet
register_asset "stylesheets/insightful.scss"

# Register custom SVG icons
register_svg_icon "lightbulb"

after_initialize do
  # Require controller
  require_relative "controllers/insightful_controller.rb"

  # Add routes
  Discourse::Application.routes.append do
    post "/insightful/:post_id" => "insightful#create"
    delete "/insightful/:post_id" => "insightful#destroy"
    get "/insightful/:post_id/who" => "insightful#who_actioned"
  end

  require_relative "lib/insightful_cache_helper.rb"
  require_relative "lib/insightful_daily.rb"
  require_relative "lib/insightful_action_creator.rb"
  require_relative "lib/insightful_action_destroyer.rb"

  # Add UserAction constants for insightful actions
  reloadable_patch do |plugin|
    UserAction::INSIGHTFUL_GIVEN = 20 unless UserAction.const_defined?(:INSIGHTFUL_GIVEN)
    UserAction::INSIGHTFUL_RECEIVED = 21 unless UserAction.const_defined?(:INSIGHTFUL_RECEIVED)
  end

  # Add post action type for insightful using reloadable_patch
  reloadable_patch { |plugin| PostActionType.types[:insightful] = 51 }

  PostActionType.seed do |pat|
    pat.id = 51
    pat.name_key = "insightful"
    pat.is_flag = false
    pat.icon = "lightbulb"
    pat.position = 4
  end

  # Add insightful action summary (following like button pattern)
  add_to_serializer(:post, :insightful_count) { object.insightful_count || 0 }

  add_to_serializer(:post, :insightfuled) do
    return false unless scope.user
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    PostAction.exists?(
      post: object,
      user: scope.user,
      post_action_type_id: insightful_type_id,
      deleted_at: nil,
    )
  end

  add_to_serializer(:post, :can_undo_insightful) do
    return false unless scope.user
    return false unless SiteSetting.insightful_enabled

    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    PostAction.exists?(
      post: object,
      user: scope.user,
      post_action_type_id: insightful_type_id,
      deleted_at: nil,
    )
  end

  add_to_serializer(:post, :can_toggle_insightful) do
    return false unless scope.user
    return false unless SiteSetting.insightful_enabled
    return false if object.user == scope.user
    return false if object.trashed?
    return false if object.topic.archived?

    # Check basic permission first
    return false if scope.user.trust_level < SiteSetting.insightful_min_trust_level

    # Check if user has already actioned this post
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    return false unless insightful_type_id

    existing_action =
      PostAction.find_by(
        post: object,
        user: scope.user,
        post_action_type_id: insightful_type_id,
        deleted_at: nil,
      )

    if existing_action
      # User has already actioned - check if they can undo (within timeout)
      scope.can_delete_post_action?(existing_action)
    else
      # User hasn't actioned - they can act if they meet basic requirements
      true
    end
  end

  add_to_serializer(:post, :show_insightful) { SiteSetting.insightful_enabled }

  # Track insightful stats
  add_to_class(:post, :update_insightful_count) do
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    count = post_actions.where(post_action_type_id: insightful_type_id, deleted_at: nil).count
    update_column(:insightful_count, count)
  end

  # Event listeners for insightful actions - only handle MessageBus publishing
  # User stats and UserAction logging is handled by the service classes
  on(:insightful_created) do |post_action, creator|
    if post_action && creator
      post = post_action.post
      # Publish real-time update using Discourse's standard method
      post.publish_change_to_clients!(
        :insightfuled,
        { insightful_count: post.insightful_count, insightfuled_by: creator.id },
      )
    end
  end

  on(:insightful_destroyed) do |post_action, destroyer|
    if post_action && destroyer
      post = post_action.post
      # Publish real-time update using Discourse's standard method
      post.publish_change_to_clients!(
        :uninsightfuled,
        { insightful_count: post.insightful_count, insightfuled_by: destroyer.id },
      )
    end
  end

  # Extend UserAction.update_like_count to handle insightful stats
  reloadable_patch do |plugin|
    module UserActionInsightfulExtension
      def update_like_count(user_id, action_type, delta)
        if action_type == UserAction::LIKE
          UserStat.where(user_id: user_id).update_all("likes_given = likes_given + #{delta.to_i}")
        elsif action_type == UserAction::WAS_LIKED
          UserStat.where(user_id: user_id).update_all(
            "likes_received = likes_received + #{delta.to_i}",
          )
        elsif action_type == UserAction::INSIGHTFUL_GIVEN
          UserStat.where(user_id: user_id).update_all(
            "insightful_given = insightful_given + #{delta.to_i}",
          )
        elsif action_type == UserAction::INSIGHTFUL_RECEIVED
          UserStat.where(user_id: user_id).update_all(
            "insightful_received = insightful_received + #{delta.to_i}",
          )
        else
          super
        end
      end
    end

    UserAction.singleton_class.prepend(UserActionInsightfulExtension)
  end

  # No global ratelimiter instance; service layer enforces per-user daily limits

  # Add plugin directory columns for insightful stats
  add_directory_column("insightful_received", icon: "lightbulb", query: <<~SQL)
      WITH insightful_stats AS (
        SELECT
          u.id AS user_id,
          COUNT(CASE WHEN ua.action_type = #{UserAction::INSIGHTFUL_RECEIVED} AND ua.created_at > :since THEN 1 END) AS insightful_received_count
        FROM users u
        LEFT JOIN user_actions ua ON ua.user_id = u.id AND ua.created_at > :since
        WHERE u.active AND u.silenced_till IS NULL AND u.id > 0
        GROUP BY u.id
      )
      UPDATE directory_items di
      SET insightful_received = insightful_stats.insightful_received_count
      FROM insightful_stats
      WHERE insightful_stats.user_id = di.user_id
        AND di.period_type = :period_type
        AND di.insightful_received <> insightful_stats.insightful_received_count
    SQL

  add_directory_column("insightful_given", icon: "lightbulb", query: <<~SQL)
      WITH insightful_stats AS (
        SELECT
          u.id AS user_id,
          COUNT(CASE WHEN ua.action_type = #{UserAction::INSIGHTFUL_GIVEN} AND ua.created_at > :since THEN 1 END) AS insightful_given_count
        FROM users u
        LEFT JOIN user_actions ua ON ua.user_id = u.id AND ua.created_at > :since
        WHERE u.active AND u.silenced_till IS NULL AND u.id > 0
        GROUP BY u.id
      )
      UPDATE directory_items di
      SET insightful_given = insightful_stats.insightful_given_count
      FROM insightful_stats
      WHERE insightful_stats.user_id = di.user_id
        AND di.period_type = :period_type
        AND di.insightful_given <> insightful_stats.insightful_given_count
    SQL

  # Scheduled job to clean up old daily tracking records
  # TODO: Convert to proper Job class for Discourse 2026+
  # NOTE: The `every` API was removed. Need to create app/jobs/scheduled/cleanup_insightful_daily.rb
  # every :day, at: 0.hours do
  #   InsightfulDaily.cleanup_old_records(90)
  # end

  # Add user stats to serializers
  add_to_serializer(:user_summary, :insightful_given) { object.insightful_given }
  add_to_serializer(:user_summary, :insightful_received) { object.insightful_received }
end

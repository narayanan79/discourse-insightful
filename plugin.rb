# frozen_string_literal: true

# name: discourse-insightful
# about: Adds an insightful button next to the like button, allowing users to mark posts as insightful
# version: 1.1.0
# authors: narayanan79
# url: https://github.com/narayanan79/discourse-insightful
# required_version: 2026.5.0

enabled_site_setting :insightful_enabled

register_asset "stylesheets/insightful.scss"

register_svg_icon "lightbulb"

module ::DiscourseInsightful
  PLUGIN_NAME = "discourse-insightful"

  # Persisted identifiers: changing them requires a data migration.
  POST_ACTION_TYPE_ID = 51
  POST_ACTION_TYPE_NAME_KEY = "insightful"
  USER_ACTION_GIVEN = 20
  USER_ACTION_RECEIVED = 21
end

after_initialize do
  require_relative "lib/insightful_cache_helper"
  require_relative "lib/insightful_daily"
  require_relative "lib/directory_columns"
  require_relative "lib/guardian_extension"
  require_relative "lib/post_action_users_controller_extension"
  require_relative "lib/post_actions_controller_extension"
  require_relative "lib/post_serializer_extension"
  require_relative "lib/user_action_extension"
  require_relative "lib/user_summary_extension"
  require_relative "lib/insightful_action_creator"
  require_relative "lib/insightful_action_destroyer"
  require_relative "controllers/insightful_controller"
  require_relative "app/jobs/scheduled/cleanup_insightful_daily"

  register_seedfu_fixtures(File.expand_path("db/fixtures", __dir__))

  Discourse::Application.routes.append do
    constraints(post_id: /\d+/) do
      post "/insightful/:post_id" => "insightful#create"
      delete "/insightful/:post_id" => "insightful#destroy"
      get "/insightful/:post_id/who" => "insightful#who_actioned"
    end
  end

  reloadable_patch do
    ::Guardian.prepend(DiscourseInsightful::GuardianExtension)
    ::PostActionUsersController.prepend(DiscourseInsightful::PostActionUsersControllerExtension)
    ::PostActionsController.prepend(DiscourseInsightful::PostActionsControllerExtension)
    ::PostSerializer.prepend(DiscourseInsightful::PostSerializerExtension)
    ::UserAction.singleton_class.prepend(DiscourseInsightful::UserActionExtension)
    ::UserSummary.prepend(DiscourseInsightful::UserSummaryExtension)

    # Kept for code written against earlier versions of the plugin.
    # rubocop:disable Discourse/Plugins/NamespaceConstants
    if !::UserAction.const_defined?(:INSIGHTFUL_GIVEN, false)
      ::UserAction::INSIGHTFUL_GIVEN = DiscourseInsightful::USER_ACTION_GIVEN
    end
    if !::UserAction.const_defined?(:INSIGHTFUL_RECEIVED, false)
      ::UserAction::INSIGHTFUL_RECEIVED = DiscourseInsightful::USER_ACTION_RECEIVED
    end
    # rubocop:enable Discourse/Plugins/NamespaceConstants
  end

  add_to_class(:post, :update_insightful_count) do
    # Row lock first: a concurrent mark and unmark of this post then count one
    # after the other, and the later count sees the other's committed change.
    Post.where(id:).lock.pick(:id)
    type_id = DiscourseInsightful::POST_ACTION_TYPE_ID
    count = PostAction.where(post_id: id, post_action_type_id: type_id).count
    update_column(:insightful_count, count)
  end

  # Post serializer: state for the post menu button.
  add_to_serializer(:post, :insightful_count) { object.insightful_count.to_i }
  add_to_serializer(:post, :show_insightful) { SiteSetting.insightful_enabled }
  add_to_serializer(:post, :insightfuled) { insightful_post_action.present? }

  add_to_serializer(:post, :can_undo_insightful) do
    action = insightful_post_action
    action.present? && scope.can_delete_post_action?(action)
  end

  add_to_serializer(:post, :can_toggle_insightful) do
    action = insightful_post_action
    action ? scope.can_delete_post_action?(action) : scope.can_mark_post_insightful?(object)
  end

  # User summary: stats and "most insightful" lists. The lists use core's
  # serializer so `enable_names`, flair and staff fields behave like likes.
  can_see_stats = -> { scope.can_see_summary_stats?(object.user) }
  has_givers = -> { object.most_insightful_received_by_users.present? }
  has_receivers = -> { object.most_insightful_given_to_users.present? }

  add_to_serializer(:user_summary, :insightful_given, include_condition: can_see_stats) do
    object.insightful_given
  end

  add_to_serializer(:user_summary, :insightful_received, include_condition: can_see_stats) do
    object.insightful_received
  end

  add_to_serializer(
    :user_summary,
    :most_insightful_received_by_users,
    include_condition: has_givers,
  ) do
    serializer = UserSummarySerializer::UserWithCountSerializer
    users = object.most_insightful_received_by_users
    ActiveModel::ArraySerializer.new(users, each_serializer: serializer, scope:).as_json
  end

  add_to_serializer(
    :user_summary,
    :most_insightful_given_to_users,
    include_condition: has_receivers,
  ) do
    serializer = UserSummarySerializer::UserWithCountSerializer
    users = object.most_insightful_given_to_users
    ActiveModel::ArraySerializer.new(users, each_serializer: serializer, scope:).as_json
  end

  # Summary pages are cached for an hour per viewer; refresh the ones we can.
  on(:like_created) do |post_action|
    liked_user_id = post_action.post&.user_id
    InsightfulCacheHelper.invalidate_user_summary_cache(post_action.user_id, liked_user_id)
  end

  on(:like_destroyed) do |post_action|
    liked_user_id = post_action.post&.user_id
    InsightfulCacheHelper.invalidate_user_summary_cache(post_action.user_id, liked_user_id)
  end

  on(:user_destroyed) { |user| InsightfulDaily.where(user_id: user.id).delete_all }

  # User directory columns.
  columns = DiscourseInsightful::DirectoryColumns
  received_query =
    columns.query(column: columns::RECEIVED, action_type: DiscourseInsightful::USER_ACTION_RECEIVED)
  given_query =
    columns.query(column: columns::GIVEN, action_type: DiscourseInsightful::USER_ACTION_GIVEN)

  add_directory_column(columns::RECEIVED, icon: "lightbulb", query: received_query)
  add_directory_column(columns::GIVEN, icon: "lightbulb", query: given_query)

  # Runs when the plugin is switched off too (unlike `on`).
  on_enabled_change { |_old_value, new_value| columns.set_enabled(new_value) }
end

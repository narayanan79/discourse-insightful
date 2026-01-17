# frozen_string_literal: true

class InsightfulActionCreator
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  policy :can_create_insightful
  policy :within_rate_limit
  step :create_action
  step :update_post_data
  step :log_action

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def can_create_insightful(guardian:, post:)
    return false unless SiteSetting.insightful_enabled
    return false unless guardian.user
    return false if guardian.user.trust_level < SiteSetting.insightful_min_trust_level
    return false if post.user == guardian.user # Can't action your own posts
    return false if post.trashed?
    return false if post.topic.archived?
    return false if post.topic.closed?

    # Check if already actioned
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    existing_action =
      PostAction.find_by(post: post, user: guardian.user, post_action_type_id: insightful_type_id)

    return false if existing_action && existing_action.deleted_at.nil?

    true
  end

  def within_rate_limit(guardian:)
    RateLimiter.new(
      guardian.user,
      "insightful",
      SiteSetting.insightful_max_per_day,
      1.day,
    ).performed!
    true
  rescue RateLimiter::LimitExceeded
    false
  end

  def create_action(guardian:, post:)
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    return false unless insightful_type_id

    creator = PostActionCreator.new(guardian.user, post, insightful_type_id, silent: true)

    result = creator.perform
    @post_action = result.post_action

    return false unless result.success && @post_action

    # Track daily action
    InsightfulDaily.increment_for(guardian.user.id)

    # Invalidate user summary cache to ensure stats show up immediately
    InsightfulCacheHelper.invalidate_user_summary_cache(guardian.user.id, post.user.id)

    # Create UserAction records for both the giver and receiver
    # This is necessary for custom action types as PostActionCreator doesn't do this automatically
    # Note: log_action! automatically calls update_like_count to update user_stats
    UserAction.log_action!(
      action_type: UserAction::INSIGHTFUL_GIVEN,
      user_id: guardian.user.id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )

    UserAction.log_action!(
      action_type: UserAction::INSIGHTFUL_RECEIVED,
      user_id: post.user.id,
      acting_user_id: guardian.user.id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
    )

    true
  rescue => e
    Rails.logger.error("Failed to create insightful action: #{e.message}")
    false
  end

  def update_post_data(post:)
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    count =
      PostAction.where(post: post, post_action_type_id: insightful_type_id, deleted_at: nil).count

    post.update_column(:insightful_count, count)
  end

  def log_action(guardian:, post:)
    # Log to staff action log if user is staff (simplified)
    if guardian.user.staff?
      Rails.logger.info("Staff user #{guardian.user.username} marked post #{post.id} as insightful")
    end

    DiscourseEvent.trigger(:insightful_created, @post_action, guardian.user)
  end
end

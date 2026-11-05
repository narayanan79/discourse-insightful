# frozen_string_literal: true

# Removes the acting user's insightful mark from a post (within core's undo
# window, like a like). Mirrors InsightfulActionCreator: all writes are in one
# transaction, unmarks of a post are serialized by `lock(:post_id)` and the
# recount by the post row lock; side effects run after commit.
class InsightfulActionDestroyer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post

  lock(:post_id) do
    model :post_action
    policy :can_remove_post_action

    transaction do
      step :remove_post_action
      step :remove_user_actions
      step :untrack_daily_count
      step :update_post_insightful_count
    end
  end

  step :invalidate_user_summaries
  step :publish_post_change
  step :trigger_event

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def fetch_post_action(guardian:, post:)
    return if guardian.user.blank?

    PostAction.find_by(
      post_id: post.id,
      user_id: guardian.user.id,
      post_action_type_id: DiscourseInsightful::POST_ACTION_TYPE_ID,
    )
  end

  def can_remove_post_action(guardian:, post_action:)
    guardian.can_delete_post_action?(post_action)
  end

  def remove_post_action(guardian:, post_action:)
    post_action.remove_act!(guardian.user)
  end

  # Only rows that actually existed are subtracted from user_stats, and never
  # for private messages (log_action! did not count those). This keeps the
  # counters exact even for actions created before user actions were logged.
  def remove_user_actions(guardian:, post:)
    acting_user_id = guardian.user.id
    given_type = DiscourseInsightful::USER_ACTION_GIVEN
    received_type = DiscourseInsightful::USER_ACTION_RECEIVED
    rows = UserAction.where(acting_user_id: acting_user_id, target_post_id: post.id)

    given = rows.where(action_type: given_type, user_id: acting_user_id).delete_all
    received = rows.where(action_type: received_type, user_id: post.user_id).delete_all

    return if post.topic&.private_message?

    UserAction.update_like_count(acting_user_id, given_type, -given) if given > 0
    UserAction.update_like_count(post.user_id, received_type, -received) if received > 0
  end

  def untrack_daily_count(guardian:, post_action:)
    InsightfulDaily.decrement_for(guardian.user.id, post_action.created_at.to_date)
  end

  def update_post_insightful_count(post:)
    post.update_insightful_count
  end

  def invalidate_user_summaries(guardian:, post:)
    InsightfulCacheHelper.invalidate_user_summary_cache(guardian.user.id, post.user_id)
  end

  def publish_post_change(guardian:, post:)
    payload = { insightful_count: post.insightful_count, skip_topic_stats: true }
    # Who marked a post is only public when the site shows it.
    payload[:insightfuled_by] = guardian.user.id if SiteSetting.insightful_show_who_actioned
    post.publish_change_to_clients!(:uninsightfuled, payload)
  end

  def trigger_event(guardian:, post_action:)
    DiscourseEvent.trigger(:insightful_destroyed, post_action, guardian.user)
  end
end

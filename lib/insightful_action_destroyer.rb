# frozen_string_literal: true

class InsightfulActionDestroyer
  include Service::Base

  params do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  model :post
  model :post_action
  policy :can_remove_action
  step :destroy_action
  step :update_post_data
  step :log_action

  private

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def fetch_post_action(guardian:, post:)
    insightful_type_id = PostActionType.find_by(name_key: "insightful")&.id
    PostAction.find_by(post: post, user: guardian.user, post_action_type_id: insightful_type_id)
  end

  def can_remove_action(guardian:, post:, post_action:)
    return false unless post_action
    return false unless guardian.can_delete_post_action?(post_action)
    return false if post_action.deleted_at.present?
    # Allow undo at any time, like Like
    true
  end

  def destroy_action(post_action:, guardian:, post:)
    @destroyed_action = post_action

    # Soft delete the action
    post_action.remove_act!(guardian.user)

    # Decrement daily count
    InsightfulDaily.decrement_for(guardian.user.id)

    # Invalidate user summary cache to ensure stats show up immediately
    InsightfulCacheHelper.invalidate_user_summary_cache(guardian.user.id, post.user.id)

    # Remove UserAction records for both the giver and receiver
    UserAction.where(
      action_type: UserAction::INSIGHTFUL_GIVEN,
      user_id: guardian.user.id,
      target_post_id: post.id,
    ).destroy_all

    UserAction.where(
      action_type: UserAction::INSIGHTFUL_RECEIVED,
      user_id: post.user.id,
      target_post_id: post.id,
      acting_user_id: guardian.user.id,
    ).destroy_all

    true
  rescue => e
    Rails.logger.error("Failed to destroy insightful action: #{e.message}")
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
      Rails.logger.info(
        "Staff user #{guardian.user.username} removed insightful from post #{post.id}",
      )
    end

    DiscourseEvent.trigger(:insightful_destroyed, @destroyed_action, guardian.user)
  end
end

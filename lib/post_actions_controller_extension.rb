# frozen_string_literal: true

module DiscourseInsightful
  # Core's generic `/post_actions` endpoint accepts any `post_action_type_id`.
  # Type 51 is unknown to core's flag-based type registry, so core would create
  # insightful PostActions while skipping every rule and all bookkeeping this
  # plugin enforces (own posts, trust level, closed topics, daily limit,
  # user stats). Insightfuls must go through `/insightful/:post_id` instead.
  module PostActionsControllerExtension
    private

    def fetch_post_action_type_id_from_params
      super
      if @post_action_type_id == DiscourseInsightful::POST_ACTION_TYPE_ID
        raise Discourse::InvalidAccess
      end
    end
  end
end

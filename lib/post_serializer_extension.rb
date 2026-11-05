# frozen_string_literal: true

module DiscourseInsightful
  # Resolves the current user's insightful PostAction for the serialized post
  # without extra queries when the topic view has already preloaded the user's
  # post actions (the common case: rendering a topic).
  module PostSerializerExtension
    private

    def insightful_post_action
      return @insightful_post_action if defined?(@insightful_post_action)

      @insightful_post_action = lookup_insightful_post_action
    end

    def lookup_insightful_post_action
      return if scope.user.blank?

      if topic_view || post_actions || all_post_actions
        # Preloaded data covers every post in the view, so a missing entry
        # means "not insightfuled" rather than "unknown".
        actions&.dig(DiscourseInsightful::POST_ACTION_TYPE_ID)
      else
        PostAction.find_by(
          post_id: object.id,
          user_id: scope.user.id,
          post_action_type_id: DiscourseInsightful::POST_ACTION_TYPE_ID,
        )
      end
    end
  end
end

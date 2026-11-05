# frozen_string_literal: true

module DiscourseInsightful
  # Core's "who acted" endpoint (/post_action_users) lists the actors of any
  # post action type it does not know, to anyone who can see the post. For
  # insightfuls that would bypass `insightful_show_who_actioned` and the login
  # requirement of /insightful/:post_id/who.
  module PostActionUsersControllerExtension
    def index
      if params[:post_action_type_id].to_i == DiscourseInsightful::POST_ACTION_TYPE_ID
        raise Discourse::InvalidAccess
      end

      super
    end
  end
end

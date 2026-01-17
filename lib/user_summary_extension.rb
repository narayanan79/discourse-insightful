# frozen_string_literal: true

module DiscourseInsightful
  module UserSummaryExtension
    extend ActiveSupport::Concern

    def insightful_given
      @user.user_stat&.insightful_given || 0
    end

    def insightful_received
      @user.user_stat&.insightful_received || 0
    end

    def most_insightful_received_by_users
      insightful_givers = {}
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(user: @user)
        .where(action_type: UserAction::INSIGHTFUL_RECEIVED)
        .group(:acting_user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("acting_user_id, COUNT(*)")
        .each { |l| insightful_givers[l[0]] = l[1] }

      user_counts(insightful_givers)
    end

    def most_insightful_given_to_users
      insightful_receivers = {}
      UserAction
        .joins(:target_topic, :target_post)
        .merge(Topic.listable_topics.visible.secured(@guardian))
        .where(action_type: UserAction::INSIGHTFUL_RECEIVED)
        .where(acting_user_id: @user.id)
        .group(:user_id)
        .order("COUNT(*) DESC")
        .limit(UserSummary::MAX_SUMMARY_RESULTS)
        .pluck("user_actions.user_id, COUNT(*)")
        .each { |l| insightful_receivers[l[0]] = l[1] }

      user_counts(insightful_receivers)
    end
  end
end

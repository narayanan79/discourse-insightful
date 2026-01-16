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
  end
end

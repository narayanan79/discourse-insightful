# frozen_string_literal: true

module Jobs
  # Keeps the insightful_daily reporting table bounded.
  class CleanupInsightfulDaily < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return if !SiteSetting.insightful_enabled

      ::InsightfulDaily.cleanup_old_records
    end
  end
end

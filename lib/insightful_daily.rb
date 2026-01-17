# frozen_string_literal: true

class InsightfulDaily < ActiveRecord::Base
  self.table_name = "insightful_daily"

  belongs_to :user

  validates :user_id, presence: true, uniqueness: { scope: :insightful_date }
  validates :insightful_date, presence: true
  validates :insightful_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.increment_for(user_id)
    date = Date.current

    # Use atomic SQL update to prevent race conditions
    result =
      where(user_id: user_id, insightful_date: date).update_all(
        "insightful_count = insightful_count + 1",
      )

    # If no record was updated, create one
    if result == 0
      begin
        create!(user_id: user_id, insightful_date: date, insightful_count: 1)
      rescue ActiveRecord::RecordNotUnique
        # Another thread created it, retry the update
        retry
      end
    end

    # Return the record (optional, for backward compatibility)
    find_by(user_id: user_id, insightful_date: date)
  end

  def self.decrement_for(user_id)
    date = Date.current

    # Use atomic SQL update with GREATEST to prevent negative counts
    where(user_id: user_id, insightful_date: date).where("insightful_count > 0").update_all(
      "insightful_count = insightful_count - 1",
    )

    # Return the record (optional, for backward compatibility)
    find_by(user_id: user_id, insightful_date: date)
  end

  def self.count_for(user_id, date = Date.current)
    where(user_id: user_id, insightful_date: date).pluck(:insightful_count).first || 0
  end

  def self.within_daily_limit?(user_id, limit = SiteSetting.insightful_max_per_day)
    count_for(user_id) < limit
  end

  def self.cleanup_old_records(days_to_keep = 30)
    where("insightful_date < ?", days_to_keep.days.ago).delete_all
  end
end

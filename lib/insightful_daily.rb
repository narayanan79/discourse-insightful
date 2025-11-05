# frozen_string_literal: true

class InsightfulDaily < ActiveRecord::Base
  self.table_name = "insightful_daily"

  belongs_to :user

  validates :user_id, presence: true, uniqueness: { scope: :insightful_date }
  validates :insightful_date, presence: true
  validates :insightful_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.increment_for(user_id)
    date = Date.current

    daily_record =
      find_or_create_by(user_id: user_id, insightful_date: date) do |record|
        record.insightful_count = 0
      end

    daily_record.increment!(:insightful_count)
    daily_record
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition
    retry
  end

  def self.decrement_for(user_id)
    date = Date.current

    daily_record = find_by(user_id: user_id, insightful_date: date)

    return unless daily_record && daily_record.insightful_count > 0

    daily_record.decrement!(:insightful_count)
    daily_record
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

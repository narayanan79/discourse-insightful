# frozen_string_literal: true

# Per-user, per-day count of insightfuls given. This is reporting data; the
# daily limit itself is enforced by `RateLimiter` in InsightfulController.
class InsightfulDaily < ActiveRecord::Base
  self.table_name = "insightful_daily"

  DEFAULT_RETENTION_DAYS = 90

  belongs_to :user

  validates :user_id, presence: true, uniqueness: { scope: :insightful_date }
  validates :insightful_date, presence: true
  validates :insightful_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Atomic upsert: safe under concurrent requests without retries.
  def self.increment_for(user_id, date = Date.current)
    DB.exec(<<~SQL, user_id: user_id, date: date)
      INSERT INTO insightful_daily
        (user_id, insightful_date, insightful_count, created_at, updated_at)
      VALUES (:user_id, :date, 1, NOW(), NOW())
      ON CONFLICT (user_id, insightful_date)
      DO UPDATE SET insightful_count = insightful_daily.insightful_count + 1, updated_at = NOW()
    SQL
  end

  # `date` should be the day the action was originally created.
  def self.decrement_for(user_id, date = Date.current)
    rows = where(user_id: user_id, insightful_date: date).where("insightful_count > 0")
    rows.update_all(["insightful_count = insightful_count - 1, updated_at = ?", Time.zone.now])
  end

  def self.count_for(user_id, date = Date.current)
    where(user_id: user_id, insightful_date: date).pick(:insightful_count) || 0
  end

  def self.cleanup_old_records(days_to_keep = DEFAULT_RETENTION_DAYS)
    where("insightful_date < ?", days_to_keep.days.ago.to_date).delete_all
  end
end

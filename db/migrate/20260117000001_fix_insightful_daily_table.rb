# frozen_string_literal: true

class FixInsightfulDailyTable < ActiveRecord::Migration[7.0]
  def up
    # Drop the incorrectly named table if it exists
    drop_table :insightful_dailies if table_exists?(:insightful_dailies)

    # Create the correctly named table if it doesn't exist
    unless table_exists?(:insightful_daily)
      create_table :insightful_daily do |t|
        t.references :user, null: false, foreign_key: true
        t.date :insightful_date, null: false
        t.integer :insightful_count, default: 0, null: false
        t.timestamps
      end

      add_index :insightful_daily, [:user_id, :insightful_date], unique: true, name: 'index_insightful_daily_on_user_id_and_date'
      add_index :insightful_daily, :insightful_date, name: 'index_insightful_daily_on_date'
    end
  end

  def down
    drop_table :insightful_daily if table_exists?(:insightful_daily)

    # Recreate the old incorrect table for rollback
    unless table_exists?(:insightful_dailies)
      create_table :insightful_dailies do |t|
        t.integer :user_id, null: false
        t.integer :insightful_given, default: 0, null: false
        t.date :given_date, null: false
        t.timestamps
      end

      add_index :insightful_dailies, [:user_id, :given_date], unique: true
    end
  end
end

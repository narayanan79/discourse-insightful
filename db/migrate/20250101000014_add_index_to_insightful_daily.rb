# frozen_string_literal: true

class AddIndexToInsightfulDaily < ActiveRecord::Migration[7.0]
  def change
    # Add composite index on user_id and insightful_date for fast lookups
    # This index supports the common query pattern: WHERE user_id = X AND insightful_date = Y
    add_index :insightful_daily,
              [:user_id, :insightful_date],
              unique: true,
              name: "index_insightful_daily_on_user_and_date"
  end
end

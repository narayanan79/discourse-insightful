# frozen_string_literal: true

class CreateInsightfulDailyTable < ActiveRecord::Migration[7.0]
  def change
    create_table :insightful_dailies do |t|
      t.integer :user_id, null: false
      t.integer :insightful_given, default: 0, null: false
      t.date :given_date, null: false
      t.timestamps
    end

    add_index :insightful_dailies, [:user_id, :given_date], unique: true
  end
end

# frozen_string_literal: true

class CreateInsightfulDailyTable < ActiveRecord::Migration[7.0]
  def up
    create_table :insightful_daily do |t|
      t.references :user, null: false, foreign_key: true
      t.date :insightful_date, null: false
      t.integer :insightful_count, default: 0, null: false
      t.timestamps
    end

    add_index :insightful_daily, [:user_id, :insightful_date], unique: true, name: 'index_insightful_daily_on_user_id_and_date'
    add_index :insightful_daily, :insightful_date, name: 'index_insightful_daily_on_date'
  end

  def down
    drop_table :insightful_daily
  end
end

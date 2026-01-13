# frozen_string_literal: true

class AddInsightfulCountToPosts < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :insightful_count, :integer, default: 0, null: false
  end
end

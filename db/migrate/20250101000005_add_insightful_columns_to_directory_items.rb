# frozen_string_literal: true

class AddInsightfulColumnsToDirectoryItems < ActiveRecord::Migration[7.1]
  def up
    add_column :directory_items, :insightful_received, :integer, null: false, default: 0
    add_column :directory_items, :insightful_given, :integer, null: false, default: 0

    # Add indexes for sorting by insightful columns
    add_index :directory_items, :insightful_received
    add_index :directory_items, :insightful_given
  end

  def down
    remove_column :directory_items, :insightful_received
    remove_column :directory_items, :insightful_given
  end
end

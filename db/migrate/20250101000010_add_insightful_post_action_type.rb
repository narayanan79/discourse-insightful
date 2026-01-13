# frozen_string_literal: true

class AddInsightfulPostActionType < ActiveRecord::Migration[7.0]
  def up
    # Insert only if doesn't exist
    execute <<~SQL
      INSERT INTO post_action_types (name_key, is_flag, icon, position, created_at, updated_at)
      SELECT 'insightful', false, 'lightbulb', 4, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM post_action_types WHERE name_key = 'insightful'
      )
    SQL
  end

  def down
    execute "DELETE FROM post_action_types WHERE name_key = 'insightful'"
  end
end

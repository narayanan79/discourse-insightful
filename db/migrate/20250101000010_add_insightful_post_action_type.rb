# frozen_string_literal: true

class AddInsightfulPostActionType < ActiveRecord::Migration[7.0]
  # Plain SQL so the migration does not depend on application models.
  # db/fixtures/001_insightful_post_action_type.rb keeps the row up to date.
  def up
    execute <<~SQL
      INSERT INTO post_action_types (id, name_key, is_flag, icon, position, created_at, updated_at)
      SELECT 51, 'insightful', FALSE, 'lightbulb', 4, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM post_action_types WHERE id = 51 OR name_key = 'insightful'
      )
    SQL
  end

  def down
    execute "DELETE FROM post_action_types WHERE name_key = 'insightful'"
  end
end

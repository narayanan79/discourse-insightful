# frozen_string_literal: true

# Runs during `db:migrate` (seed fixtures), never at boot, so asset builds and
# SKIP_DB_AND_REDIS boots are unaffected.
PostActionType.seed do |post_action_type|
  post_action_type.id = DiscourseInsightful::POST_ACTION_TYPE_ID
  post_action_type.name_key = DiscourseInsightful::POST_ACTION_TYPE_NAME_KEY
  post_action_type.is_flag = false
  post_action_type.icon = "lightbulb"
  post_action_type.position = 4
end

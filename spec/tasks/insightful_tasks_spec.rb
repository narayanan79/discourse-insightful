# frozen_string_literal: true

RSpec.describe "insightful rake tasks" do
  fab!(:giver) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:receiver, :user)
  fab!(:target_post) { Fabricate(:post, user: receiver) }

  before do
    Rake::Task.clear
    silence_warnings { Discourse::Application.load_tasks }
    # Without an engine, the plugin's lib/tasks is only added to the rake
    # command line (Rake.add_rakelib), not to Rails' load_tasks.
    if !Rake::Task.task_defined?("insightful:recalculate_stats")
      Dir[File.expand_path("../../lib/tasks/*.rake", __dir__)].each do |file|
        Rake.load_rakefile(file)
      end
    end
    enable_current_plugin
    InsightfulActionCreator.call(params: { post_id: target_post.id }, guardian: giver.guardian)
  end

  describe "insightful:recalculate_stats" do
    it "repairs drifted counters" do
      giver.user_stat.update!(insightful_given: -2)
      receiver.user_stat.update!(insightful_received: 7)
      target_post.update_columns(insightful_count: 5)

      capture_stdout { invoke_rake_task("insightful:recalculate_stats") }

      expect(giver.user_stat.reload.insightful_given).to eq(1)
      expect(receiver.user_stat.reload.insightful_received).to eq(1)
      expect(target_post.reload.insightful_count).to eq(1)
    end
  end

  describe "insightful:backfill_user_actions" do
    it "recreates missing user actions and skips posts that were deleted for good" do
      UserAction.where(target_post_id: target_post.id).delete_all
      type_id = DiscourseInsightful::POST_ACTION_TYPE_ID
      Fabricate(:post_action, post_action_type_id: type_id).update_columns(post_id: -1)

      capture_stdout { invoke_rake_task("insightful:backfill_user_actions") }

      action_types = UserAction.where(target_post_id: target_post.id).pluck(:action_type)
      expect(action_types).to contain_exactly(
        DiscourseInsightful::USER_ACTION_GIVEN,
        DiscourseInsightful::USER_ACTION_RECEIVED,
      )
    end
  end
end

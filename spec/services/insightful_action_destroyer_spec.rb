# frozen_string_literal: true

RSpec.describe InsightfulActionDestroyer do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user) { Fabricate(:user, trust_level: TrustLevel[1]) }
    fab!(:author, :user)
    fab!(:topic) { Fabricate(:topic, user: author) }
    fab!(:post) { Fabricate(:post, topic:, user: author) }

    let(:params) { { post_id: post.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:type_id) { DiscourseInsightful::POST_ACTION_TYPE_ID }

    before do
      enable_current_plugin
      InsightfulActionCreator.call(params: { post_id: post.id }, guardian: acting_user.guardian)
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when post is not found" do
      let(:params) { { post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user has not marked the post" do
      let(:dependencies) { { guardian: Fabricate(:user).guardian } }

      it { is_expected.to fail_to_find_a_model(:post_action) }
    end

    context "when the undo window has passed" do
      before { freeze_time(SiteSetting.post_undo_action_window_mins.minutes.from_now + 1.minute) }

      it { is_expected.to fail_a_policy(:can_remove_post_action) }
    end

    context "when everything is valid" do
      let(:messages) { MessageBus.track_publish("/topic/#{topic.id}") { result } }
      let(:events) { DiscourseEvent.track_events(:insightful_destroyed) { result } }

      it { is_expected.to run_successfully }

      it "removes the post action" do
        expect { result }.to change {
          PostAction.where(post:, user: acting_user, post_action_type_id: type_id).count
        }.from(1).to(0)
      end

      it "updates the post's insightful count" do
        expect { result }.to change { post.reload.insightful_count }.from(1).to(0)
      end

      it "removes user actions and decrements stats exactly once" do
        acting_user.user_stat.update!(insightful_given: 5)
        author.user_stat.update!(insightful_received: 5)

        result

        expect(UserAction.where(target_post_id: post.id)).to be_empty
        expect(acting_user.user_stat.reload.insightful_given).to eq(4)
        expect(author.user_stat.reload.insightful_received).to eq(4)
      end

      it "untracks the daily count" do
        expect { result }.to change { InsightfulDaily.count_for(acting_user.id) }.from(1).to(0)
      end

      it "publishes only the insightful change to the topic channel" do
        expect(messages.size).to eq(1)
        expect(messages.first.data).to include(
          type: :uninsightfuled,
          id: post.id,
          insightful_count: 0,
          insightfuled_by: acting_user.id,
        )
      end

      it "triggers the insightful_destroyed event" do
        expect(events.size).to eq(1)
        expect(events.first[:params].last).to eq(acting_user)
      end
    end

    context "when the post is in a private message" do
      fab!(:post) { Fabricate(:private_message_post, user: author, recipient: acting_user) }

      it "leaves user stats untouched, as they never counted the action" do
        acting_user.user_stat.update!(insightful_given: 5)
        author.user_stat.update!(insightful_received: 5)

        expect(result).to run_successfully
        expect(acting_user.user_stat.reload.insightful_given).to eq(5)
        expect(author.user_stat.reload.insightful_received).to eq(5)
      end
    end

    context "when the action predates user action logging" do
      before do
        UserAction.where(target_post_id: post.id).delete_all
        acting_user.user_stat.update!(insightful_given: 3)
      end

      it "does not decrement stats for rows that never existed" do
        expect(result).to run_successfully
        expect(acting_user.user_stat.reload.insightful_given).to eq(3)
      end
    end
  end
end

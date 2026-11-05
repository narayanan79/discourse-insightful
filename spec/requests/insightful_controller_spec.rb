# frozen_string_literal: true

RSpec.describe InsightfulController do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:target_post) { Fabricate(:post, topic:, user: author) }

  before { enable_current_plugin }

  describe "#create" do
    it "requires the user to be logged in" do
      post "/insightful/#{target_post.id}.json"

      expect(response.status).to eq(403)
    end

    it "is not routable when the plugin is disabled" do
      SiteSetting.insightful_enabled = false
      sign_in(user)

      post "/insightful/#{target_post.id}.json"

      expect(response.status).to eq(404)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "marks the post and returns its new state" do
        post "/insightful/#{target_post.id}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to include(
          "success" => true,
          "insightful_count" => 1,
          "acted" => true,
          "insightfuled" => true,
          "can_toggle_insightful" => true,
          "can_undo_insightful" => true,
        )
      end

      it "returns 404 for a post that does not exist" do
        post "/insightful/0.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to eq([I18n.t("insightful.errors.post_not_found")])
      end

      it "reveals nothing about posts the user cannot see" do
        hidden_post = Fabricate(:private_message_post, user: author)
        hidden_post.update_columns(insightful_count: 3)

        post "/insightful/#{hidden_post.id}.json"

        expect(response.status).to eq(403)
        expect(response.parsed_body).not_to have_key("insightful_count")
        expect(PostAction.where(post: hidden_post)).to be_empty
      end

      it "answers 503 when the post lock cannot be taken (read-only Redis)" do
        DistributedMutex.stubs(:synchronize).raises(Discourse::ReadOnly)

        post "/insightful/#{target_post.id}.json"

        expect(response.status).to eq(503)
        expect(PostAction.where(post: target_post)).to be_empty
      end

      it "refuses to mark the same post twice" do
        post "/insightful/#{target_post.id}.json"
        post "/insightful/#{target_post.id}.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq([I18n.t("insightful.errors.already_actioned")])
      end

      it "is refused for non-staff when the daily limit is 0" do
        SiteSetting.insightful_max_per_day = 0

        post "/insightful/#{target_post.id}.json"

        expect(response.status).to eq(403)
        expect(PostAction.where(post: target_post)).to be_empty
      end

      context "with the daily limit" do
        before do
          RateLimiter.enable
          SiteSetting.insightful_max_per_day = 1
        end

        it "counts only successful marks towards the limit" do
          own_post = Fabricate(:post, user:)

          post "/insightful/#{own_post.id}.json"
          expect(response.status).to eq(403)

          post "/insightful/#{target_post.id}.json"
          expect(response.status).to eq(200)

          post "/insightful/#{Fabricate(:post).id}.json"
          expect(response.status).to eq(429)
        end
      end
    end
  end

  describe "#destroy" do
    before { sign_in(user) }

    it "removes the mark and returns the new state" do
      post "/insightful/#{target_post.id}.json"

      delete "/insightful/#{target_post.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "success" => true,
        "insightful_count" => 0,
        "insightfuled" => false,
        "can_toggle_insightful" => true,
      )
    end

    it "returns 404 when the user has not marked the post" do
      delete "/insightful/#{target_post.id}.json"

      expect(response.status).to eq(404)
      expect(response.parsed_body["errors"]).to eq([I18n.t("insightful.errors.not_actioned")])
    end

    it "returns 403 once the undo window has passed" do
      post "/insightful/#{target_post.id}.json"
      PostAction.where(post: target_post, user:).update_all(created_at: 1.day.ago)

      delete "/insightful/#{target_post.id}.json"

      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to eq([I18n.t("insightful.errors.timeout")])
    end
  end

  describe "#who_actioned" do
    fab!(:first_actor, :user)
    fab!(:second_actor, :user)

    before do
      [first_actor, second_actor].each do |actor|
        InsightfulActionCreator.call(params: { post_id: target_post.id }, guardian: actor.guardian)
      end
      sign_in(user)
    end

    it "lists the users who marked the post, oldest first, with the total" do
      get "/insightful/#{target_post.id}/who.json"

      expect(response.status).to eq(200)
      ids = response.parsed_body["users"].map { |user_json| user_json["id"] }
      expect(ids).to eq([first_actor.id, second_actor.id])
      expect(response.parsed_body["total_count"]).to eq(2)
    end

    it "reports the real total when more users marked the post than are listed" do
      stub_const(InsightfulController, :WHO_ACTIONED_LIMIT, 1) do
        get "/insightful/#{target_post.id}/who.json"
      end

      expect(response.parsed_body["users"].size).to eq(1)
      expect(response.parsed_body["total_count"]).to eq(2)
    end

    it "hides users ignored by the viewer" do
      Fabricate(:ignored_user, user:, ignored_user: first_actor)

      get "/insightful/#{target_post.id}/who.json"

      ids = response.parsed_body["users"].map { |user_json| user_json["id"] }
      expect(ids).to eq([second_actor.id])
      expect(response.parsed_body["total_count"]).to eq(1)
    end

    it "is forbidden when the site hides who marked posts" do
      SiteSetting.insightful_show_who_actioned = false

      get "/insightful/#{target_post.id}/who.json"

      expect(response.status).to eq(403)
    end

    it "is forbidden for posts the viewer cannot see" do
      hidden_post = Fabricate(:private_message_post, user: author)

      get "/insightful/#{hidden_post.id}/who.json"

      expect(response.status).to eq(403)
    end
  end
end

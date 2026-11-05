# frozen_string_literal: true

RSpec.describe UserDestroyer do
  fab!(:admin)
  fab!(:giver) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:target_post, :post)

  before do
    enable_current_plugin
    InsightfulActionCreator.call(params: { post_id: target_post.id }, guardian: giver.guardian)
  end

  it "deletes users who marked posts as insightful, including their daily rows" do
    expect(InsightfulDaily.where(user_id: giver.id)).to exist

    described_class.new(admin).destroy(giver)

    expect(User.exists?(giver.id)).to eq(false)
    expect(InsightfulDaily.where(user_id: giver.id)).to be_empty
  end
end

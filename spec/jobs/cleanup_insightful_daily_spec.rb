# frozen_string_literal: true

RSpec.describe Jobs::CleanupInsightfulDaily do
  fab!(:user)

  before { enable_current_plugin }

  it "removes daily rows older than the retention period" do
    InsightfulDaily.increment_for(user.id, 100.days.ago.to_date)
    InsightfulDaily.increment_for(user.id, Date.current)

    expect { described_class.new.execute({}) }.to change { InsightfulDaily.count }.from(2).to(1)
  end
end

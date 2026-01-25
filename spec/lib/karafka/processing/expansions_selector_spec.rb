# frozen_string_literal: true

RSpec.describe_current do
  subject(:expansions) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context "when inline insights are disabled" do
    it { expect(expansions).to eq([]) }
  end

  context "when inline insights are enabled" do
    before { topic.inline_insights(true) }

    it { expect(expansions).to eq([Karafka::Processing::InlineInsights::Consumer]) }
  end
end

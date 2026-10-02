# frozen_string_literal: true

RSpec.describe_current do
  subject(:selector) { described_class.new }

  let(:topic) { build(:routing_share_topic) }

  describe "#find" do
    context "when no features are enabled" do
      it { expect(selector.find(topic)).to eq(Karafka::Processing::ShareGroups::Strategies::Default) }
    end

    context "when dead letter queue is enabled" do
      before { topic.dead_letter_queue(topic: "dlq") }

      it { expect(selector.find(topic)).to eq(Karafka::Processing::ShareGroups::Strategies::Dlq) }
    end
  end
end

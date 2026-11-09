# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_share_topic, name: "share-#{SecureRandom.hex(6)}") }

  it { expect(described_class).to eq(Karafka::Routing::Features::ConsumerGroups::Declaratives::Topic) }

  it { expect(Karafka::Routing::ShareGroups::Topic.ancestors).to include(described_class) }

  describe "#declaratives" do
    context "when we use declaratives without any arguments without config exec" do
      it { expect(topic.declaratives.active?).to be(true) }
      it { expect(topic.declaratives.partitions).to eq(1) }
    end

    context "when we use declaratives with custom settings" do
      before { topic.config(partitions: 5, "cleanup.policy": "compact") }

      it { expect(topic.declaratives.partitions).to eq(5) }
      it { expect(topic.declaratives.details[:"cleanup.policy"]).to eq("compact") }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h[:declaratives]).to eq(topic.declaratives.to_h) }
  end

  describe "repository integration" do
    it "registers the share-group topic in the declaratives repository" do
      topic.config(partitions: 3)

      expect(Karafka::App.declaratives.find_topic(topic.name).partitions).to eq(3)
    end
  end
end

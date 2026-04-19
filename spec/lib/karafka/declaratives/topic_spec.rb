# frozen_string_literal: true

RSpec.describe Karafka::Declaratives::Topic do
  subject(:topic) { described_class.new(:orders) }

  describe "#name" do
    it { expect(topic.name).to eq("orders") }
  end

  describe "#active / #active?" do
    it "defaults to true" do
      expect(topic.active?).to be(true)
      expect(topic.active).to be(true)
    end

    context "when set to false via DSL method" do
      before { topic.active(false) }

      it { expect(topic.active?).to be(false) }
    end

    context "when set via writer" do
      before { topic.active = false }

      it { expect(topic.active?).to be(false) }
    end
  end

  describe "#partitions" do
    it "defaults to 1" do
      expect(topic.partitions).to eq(1)
    end

    context "when set via DSL method" do
      before { topic.partitions(10) }

      it { expect(topic.partitions).to eq(10) }
    end

    context "when set via writer" do
      before { topic.partitions = 20 }

      it { expect(topic.partitions).to eq(20) }
    end
  end

  describe "#replication_factor" do
    it "defaults to 1" do
      expect(topic.replication_factor).to eq(1)
    end

    context "when set via DSL method" do
      before { topic.replication_factor(3) }

      it { expect(topic.replication_factor).to eq(3) }
    end

    context "when set via writer" do
      before { topic.replication_factor = 5 }

      it { expect(topic.replication_factor).to eq(5) }
    end
  end

  describe "#config / #details" do
    it "defaults to empty hash" do
      expect(topic.details).to eq({})
    end

    context "when setting config entries" do
      before { topic.config("retention.ms": 604_800_000) }

      it { expect(topic.details).to eq("retention.ms": 604_800_000) }
    end

    context "when setting config entries with string keys" do
      before { topic.config("cleanup.policy" => "delete") }

      it { expect(topic.details).to eq("cleanup.policy": "delete") }
    end

    context "when merging multiple config calls" do
      before do
        topic.config("retention.ms": 604_800_000)
        topic.config("cleanup.policy": "delete")
      end

      it "merges both entries" do
        expect(topic.details).to eq(
          "retention.ms": 604_800_000,
          "cleanup.policy": "delete"
        )
      end
    end
  end

  describe "#to_h" do
    before do
      topic.partitions(10)
      topic.replication_factor(3)
      topic.config("retention.ms": 604_800_000)
    end

    it "returns a hash with all attributes" do
      expect(topic.to_h).to eq(
        active: true,
        partitions: 10,
        replication_factor: 3,
        details: { "retention.ms": 604_800_000 }
      )
    end
  end
end

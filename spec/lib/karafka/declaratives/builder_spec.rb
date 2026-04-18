# frozen_string_literal: true

RSpec.describe Karafka::Declaratives::Builder do
  subject(:builder) { described_class.new }

  describe "#draw" do
    it "evaluates the block in the builder context" do
      builder.draw do
        topic :orders do
          partitions 10
          replication_factor 3
        end
      end

      topics = builder.topics
      expect(topics.size).to eq(1)
      expect(topics.first.name).to eq("orders")
      expect(topics.first.partitions).to eq(10)
      expect(topics.first.replication_factor).to eq(3)
    end

    it "supports multiple draw calls (additive)" do
      builder.draw do
        topic :orders do
          partitions 10
        end
      end

      builder.draw do
        topic :events do
          partitions 50
        end
      end

      expect(builder.topics.size).to eq(2)
    end

    it "supports config entries inside topic blocks" do
      builder.draw do
        topic :orders do
          partitions 10
          config "retention.ms" => 604_800_000
          config "cleanup.policy": "delete"
        end
      end

      topic = builder.find_topic(:orders)
      expect(topic.details).to eq(
        "retention.ms": 604_800_000,
        "cleanup.policy": "delete"
      )
    end
  end

  describe "#topic" do
    it "creates a new topic declaration" do
      declaration = builder.topic(:orders)
      expect(declaration).to be_a(Karafka::Declaratives::Topic)
      expect(declaration.name).to eq("orders")
    end

    it "returns the same declaration for the same name" do
      first = builder.topic(:orders)
      second = builder.topic(:orders)
      expect(first).to equal(second)
    end

    it "evaluates the block on the declaration" do
      builder.topic(:orders) do
        partitions 10
      end

      expect(builder.find_topic(:orders).partitions).to eq(10)
    end
  end

  describe "#topics" do
    it "returns only active topics" do
      builder.draw do
        topic :active_one do
          partitions 5
        end

        topic :inactive_one do
          active false
        end
      end

      topics = builder.topics
      expect(topics.size).to eq(1)
      expect(topics.first.name).to eq("active_one")
    end
  end

  describe "#find_topic" do
    it "returns nil for unknown topics" do
      expect(builder.find_topic(:unknown)).to be_nil
    end

    it "returns the topic if declared" do
      builder.topic(:orders)
      expect(builder.find_topic(:orders)).to be_a(Karafka::Declaratives::Topic)
    end
  end

  describe "#repository" do
    it "returns the repository instance" do
      expect(builder.repository).to be_a(Karafka::Declaratives::Repository)
    end
  end
end

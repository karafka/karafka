# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new(topics) }

  let(:topics) { create(:routing_topics) }
  let(:topic) { topics.first }
  let(:topic_name) { topic.name }

  describe "#find_or_create" do
    context "when coordinator did not exist" do
      it "expect to create one" do
        expect(buffer.find_or_create(topic_name, 1)).to be_a(Karafka::Processing::ConsumerGroups::Coordinator)
      end
    end

    context "when coordinator did exist" do
      let(:existing) { buffer.find_or_create(topic_name, 1) }

      before { existing }

      it "expect to use instance we already have" do
        expect(buffer.find_or_create(topic_name, 1)).to eq(existing)
      end
    end
  end

  describe "#resume" do
    context "when nothing to resume" do
      it { expect { |block| buffer.resume(&block) }.not_to yield_with_args }
    end

    context "when partition to resume" do
      let(:existing) { buffer.find_or_create(topic_name, 1) }

      before do
        existing.pause_tracker.pause
        existing.pause_tracker.expire
      end

      it "expect to delegate to pauses manager" do
        expect { |block| buffer.resume(&block) }.to yield_with_args(topic, 1)
      end
    end
  end

  describe "#revoke" do
    let(:existing) { buffer.find_or_create(topic_name, 1) }

    context "when revoking the last partition of a topic" do
      before do
        existing
        buffer.revoke(topic_name, 1)
      end

      it "expect to remove coordinator" do
        expect(buffer.find_or_create(topic_name, 1)).not_to eq(existing)
      end

      it "expect to drop the topic entry entirely" do
        coordinators = buffer.instance_variable_get(:@coordinators)
        expect(coordinators).not_to have_key(topic_name)
      end
    end

    context "when the topic has other partitions left" do
      let(:other) { buffer.find_or_create(topic_name, 2) }

      before do
        existing
        other
        buffer.revoke(topic_name, 1)
      end

      it "expect to keep only the remaining partition under the topic" do
        coordinators = buffer.instance_variable_get(:@coordinators)
        expect(coordinators[topic_name]).to eq(2 => other)
      end
    end

    context "when revoking an unknown topic" do
      before { buffer.revoke("unknown-topic", 1) }

      it "expect not to create any entry for it" do
        coordinators = buffer.instance_variable_get(:@coordinators)
        expect(coordinators).not_to have_key("unknown-topic")
      end
    end

    context "when revoking an unknown partition of a known topic" do
      before do
        existing
        buffer.revoke(topic_name, 999)
      end

      it "expect to leave the existing partition untouched" do
        coordinators = buffer.instance_variable_get(:@coordinators)
        expect(coordinators[topic_name]).to eq(1 => existing)
      end
    end
  end
end

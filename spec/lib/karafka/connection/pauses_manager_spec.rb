# frozen_string_literal: true

RSpec.describe_current do
  subject(:manager) { described_class.new }

  let(:topic) { build(:routing_topic) }
  let(:partition) { rand(0..100) }
  let(:fetched_pause) { manager.fetch(topic, partition) }

  describe "#fetch" do
    context "when a pause is already present" do
      let(:prefetch_pause) { manager.fetch(topic, partition) }

      before { prefetch_pause }

      it { expect(fetched_pause).to eq(prefetch_pause) }
    end

    context "when pause for given topic partition was not present" do
      it { expect(fetched_pause).to be_a(Karafka::TimeTrackers::Pause) }
    end
  end

  describe "#resume" do
    context "when there is no pause that is expired" do
      before { fetched_pause }

      it { expect { |block| manager.resume(&block) }.not_to yield_control }
    end

    context "when there is a paused and expired pause" do
      before do
        fetched_pause.pause
        sleep 0.001
      end

      it "expect to resume it" do
        manager.resume { nil }
        expect(fetched_pause.paused?).to be(false)
        expect(fetched_pause.expired?).to be(true)
      end

      it "expect to yield upon it with pause ownership details" do
        expect { |block| manager.resume(&block) }.to yield_with_args(topic, partition)
      end
    end
  end

  describe "#revoke" do
    context "when a pause is present and currently paused" do
      before do
        fetched_pause.increment
        fetched_pause.increment
        fetched_pause.pause
      end

      it "expect to reset its attempt count" do
        manager.revoke(topic, partition)
        expect(fetched_pause.attempt).to eq(0)
      end

      it "expect to keep the same tracker instance (not remove it)" do
        manager.revoke(topic, partition)
        expect(manager.fetch(topic, partition)).to eq(fetched_pause)
      end

      it "expect to leave it paused" do
        manager.revoke(topic, partition)
        expect(fetched_pause.paused?).to be(true)
      end
    end

    context "when a pause is present but not currently paused" do
      before do
        fetched_pause.increment
        fetched_pause.increment
      end

      it "expect to remove its tracker entirely" do
        manager.revoke(topic, partition)
        expect(manager.fetch(topic, partition)).not_to eq(fetched_pause)
      end

      it "expect a freshly fetched tracker afterwards to have a reset attempt count" do
        manager.revoke(topic, partition)
        expect(manager.fetch(topic, partition).attempt).to eq(0)
      end
    end
  end

  describe "#delete" do
    context "when the topic partition pause is the only one for that topic" do
      before { fetched_pause }

      it "expect to remove it and drop the topic entry" do
        manager.delete(topic, partition)
        pauses = manager.instance_variable_get(:@pauses)
        expect(pauses).not_to have_key(topic)
      end
    end

    context "when the topic has other paused partitions left" do
      let(:other_partition) { partition + 1 }
      let(:other_pause) { manager.fetch(topic, other_partition) }

      before do
        fetched_pause
        other_pause
      end

      it "expect to remove only the given partition" do
        manager.delete(topic, partition)
        pauses = manager.instance_variable_get(:@pauses)
        expect(pauses[topic]).to eq(other_partition => other_pause)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new }

  let(:topic_name) { "topic" }

  def message(partition, offset, topic = topic_name)
    build(:kafka_fetched_message, topic: topic, partition: partition, offset: offset)
  end

  def rewound(*messages)
    messages.each { |message| tracker.track(message) }
    tracker.rewound&.map { |message| [message.topic, message.partition, message.offset] }
  end

  describe "#track and #rewound" do
    context "when nothing was tracked" do
      it { expect(tracker.rewound).to be_nil }
    end

    context "when offsets go forward" do
      it { expect(rewound(message(0, 0), message(0, 1), message(1, 0), message(0, 2))).to be_nil }
    end

    context "when offsets go back within a run of one partition" do
      it { expect(rewound(message(0, 5), message(0, 0))).to eq([[topic_name, 0, 0]]) }
    end

    context "when offsets go back after a run of another partition" do
      it do
        expect(rewound(message(0, 5), message(1, 1), message(0, 0))).to eq([[topic_name, 0, 0]])
      end
    end

    context "when the same partition of another topic comes in between" do
      it do
        expect(
          rewound(message(0, 300), message(0, 0, "other"), message(0, 1, "other"), message(0, 0))
        ).to eq([[topic_name, 0, 0]])
      end
    end

    context "when the previous message of the partition was tracked before the last take" do
      before do
        tracker.track(message(0, 300))
        tracker.rewound
      end

      it { expect(rewound(message(0, 0))).to eq([[topic_name, 0, 0]]) }
    end

    context "when rewound messages were taken" do
      before { rewound(message(0, 5), message(0, 0)) }

      it { expect(tracker.rewound).to be_nil }
    end

    context "when a message that is not rewound was tracked" do
      let(:tracked) { message(0, 0) }

      before { tracker.track(tracked) }

      it "expect not to keep it" do
        expect(ObjectSpace.reachable_objects_from(tracker)).not_to include(tracked)
      end
    end
  end

  describe "#forget" do
    before do
      tracker.track(message(0, 300))
      tracker.track(message(1, 300))
    end

    context "when a partition was revoked" do
      before { tracker.forget(topic_name => [0]) }

      it "expect not to compare its later messages with offsets from before" do
        expect(rewound(message(0, 0))).to be_nil
      end

      it "expect to keep the last offsets of other partitions" do
        expect(rewound(message(0, 5), message(1, 0))).to eq([[topic_name, 1, 0]])
      end
    end

    context "when rewound messages were not taken yet" do
      before do
        tracker.track(message(1, 0))
        tracker.forget(topic_name => [0])
      end

      it { expect(tracker.rewound).to be_nil }
    end

    context "when the partition of the previous message was revoked" do
      before { tracker.forget(topic_name => [1]) }

      it { expect(rewound(message(1, 0))).to be_nil }
    end

    context "when a partition of another topic was revoked" do
      before { tracker.forget("other" => [0]) }

      it { expect(rewound(message(0, 0))).to eq([[topic_name, 0, 0]]) }
    end
  end

  describe "#store" do
    before do
      tracker.track(message(0, 300))
      tracker.store(message(0, 0))
    end

    it "expect not to check the message" do
      expect(tracker.rewound).to be_nil
    end

    it "expect to compare later messages with it" do
      expect(rewound(message(0, 1), message(1, 0), message(0, 0))).to eq([[topic_name, 0, 0]])
    end

    context "when a message was stored" do
      let(:stored) { message(1, 0) }

      before { tracker.store(stored) }

      it "expect not to keep it" do
        expect(ObjectSpace.reachable_objects_from(tracker)).not_to include(stored)
      end
    end
  end

  describe "#clear" do
    context "when rewound messages were not taken yet" do
      before do
        tracker.track(message(0, 300))
        tracker.track(message(0, 0))
        tracker.clear
      end

      it { expect(tracker.rewound).to be_nil }
    end

    context "when a message was tracked" do
      before do
        tracker.track(message(0, 300))
        tracker.clear
      end

      it { expect(rewound(message(0, 0))).to be_nil }
    end
  end
end

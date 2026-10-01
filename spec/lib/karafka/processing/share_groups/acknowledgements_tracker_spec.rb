# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new }

  let(:message) { build(:messages_message, topic: "t", partition: 0, offset: 1) }
  let(:other) { build(:messages_message, topic: "t", partition: 0, offset: 2) }

  it { expect(tracker.acknowledged?(message)).to be(false) }

  describe "#acknowledge" do
    it "expect to acknowledge a record only once" do
      expect(tracker.acknowledge(message)).to be(true)
      expect(tracker.acknowledge(message)).to be(false)
    end

    it "expect to identify records by topic, partition and offset" do
      tracker.acknowledge(message)

      expect(tracker.acknowledged?(build(:messages_message, topic: "t", partition: 0, offset: 1)))
        .to be(true)
      expect(tracker.acknowledged?(other)).to be(false)
    end
  end

  describe "#forget" do
    before do
      tracker.acknowledge(message)
      tracker.forget(message)
    end

    it { expect(tracker.acknowledged?(message)).to be(false) }
    it { expect(tracker.acknowledge(message)).to be(true) }
  end

  describe "#clear" do
    before do
      tracker.acknowledge(message)
      tracker.clear
    end

    it { expect(tracker.acknowledged?(message)).to be(false) }
    it { expect(tracker.acknowledge(message)).to be(true) }
  end
end

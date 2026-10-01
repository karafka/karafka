# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new }

  let(:first) { build(:messages_message, topic: "t", partition: 0, offset: 1) }
  let(:second) { build(:messages_message, topic: "t", partition: 0, offset: 2) }
  let(:other_partition) { build(:messages_message, topic: "t", partition: 1, offset: 1) }

  it { expect(tracker.pending?(first)).to be(false) }

  context "when records are tracked" do
    before { tracker.track([first, second, other_partition]) }

    it { expect(tracker.pending?(first)).to be(true) }

    it "identifies records by topic, partition and offset" do
      same = build(:messages_message, topic: "t", partition: 0, offset: 1)

      expect(tracker.pending?(same)).to be(true)
    end

    context "when a record is acknowledged" do
      before { tracker.acknowledged(first) }

      it { expect(tracker.pending?(first)).to be(false) }
      it { expect(tracker.pending?(other_partition)).to be(true) }
      it { expect(tracker.pending?(second)).to be(true) }
    end

    context "when cleared" do
      before { tracker.clear }

      it { expect(tracker.pending?(first)).to be(false) }
    end
  end
end

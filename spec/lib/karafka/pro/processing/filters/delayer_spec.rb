# frozen_string_literal: true

RSpec.describe_current do
  subject(:delayer) { described_class.new(5_000) }

  let(:old) { build(:messages_message, timestamp: Time.now.utc - 6) }
  let(:young) { build(:messages_message) }

  context 'when there are no messages' do
    before { delayer.apply!([]) }

    it { expect(delayer.applied?).to eq(false) }
    it { expect(delayer.timeout).to eq(0) }
    it { expect(delayer.action).to eq(:skip) }
  end

  context 'when there are only too young messages' do
    let(:messages) { [young] }

    before { delayer.apply!(messages) }

    it { expect(delayer.applied?).to eq(true) }
    it { expect(delayer.timeout).to be > 4_000 }
    it { expect(delayer.cursor).to eq(young) }
    it { expect(delayer.action).to eq(:pause) }
    it { expect(messages.size).to eq(0) }
  end

  context 'when there are only old enough messages' do
    let(:messages) { [old] }

    before { delayer.apply!(messages) }

    it { expect(delayer.applied?).to eq(false) }
    it { expect(delayer.timeout).to eq(0) }
    it { expect(delayer.action).to eq(:skip) }
    it { expect(delayer.cursor).to eq(nil) }
    it { expect(messages.size).to eq(1) }
  end

  context 'when we get some old and young messages' do
    let(:messages) { [old, young] }

    before { delayer.apply!(messages) }

    it { expect(delayer.applied?).to eq(true) }
    it { expect(delayer.timeout).to be > 4_000 }
    it { expect(delayer.action).to eq(:pause) }
    it { expect(delayer.cursor).to eq(young) }
    it { expect(messages).to eq([old]) }
  end
end

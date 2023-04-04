# frozen_string_literal: true

RSpec.describe_current do
  subject(:throttler) { described_class.new(max_messages, interval) }

  let(:max_messages) { 10 }
  let(:interval) { 100 }

  describe '#filter!' do
    context 'when no messages are throttled' do
      let(:messages) { ['message'] }

      before { throttler.filter!(messages) }

      it { expect(throttler.throttled?).to be(false) }
      it { expect(throttler.filtered?).to be(false) }
      it { expect(throttler.expired?).to be(false) }
    end

    context 'when some messages are throttled' do
      let(:throttled_message) { 'throttled_message' }
      let(:messages) { ['message', throttled_message] }

      before do
        allow(throttler).to receive(:monotonic_now).and_return(0)
        max_messages.times { throttler.filter!(['msg']) }
      end

      it 'sets #throttled? to true' do
        throttler.filter!(messages)
        expect(throttler.throttled?).to be(true)
        expect(throttler.filtered?).to be(true)
      end
    end

    context 'when some messages were throttled but expired' do
      let(:throttled_message) { 'throttled_message' }
      let(:interval) { 1 }
      let(:messages) { ['message', throttled_message] }

      before do
        max_messages.times { throttler.filter!(['msg']) }
        throttler.filter!(messages)
        sleep(0.1)
      end

      it { expect(throttler.throttled?).to be(true) }
      it { expect(throttler.filtered?).to be(true) }
      it { expect(throttler.expired?).to be(true) }
      it { expect(throttler.cursor).to eq('message') }
    end

    context 'when we hit the limit on one go but do not go beyond' do
      let(:messages) { Array.new(max_messages) { 'msg' } }

      before { allow(throttler).to receive(:monotonic_now).and_return(0) }

      it 'sets #throttled? to false' do
        throttler.filter!(messages)
        expect(throttler.throttled?).to be(false)
      end

      it 'expect not to remove last message when we reached limit' do
        throttler.filter!(messages)
        expect(messages.count).to eq(max_messages)
      end
    end

    context 'when we hit the limit on one go and go beyond' do
      let(:messages) { Array.new(max_messages + 1) { 'msg' } }

      before { allow(throttler).to receive(:monotonic_now).and_return(0) }

      it 'sets #throttled? to true' do
        throttler.filter!(messages)
        expect(throttler.throttled?).to be(true)
      end

      it 'expect not to remove last message when we reached limit' do
        throttler.filter!(messages)
        expect(messages.count).to eq(max_messages)
      end
    end
  end

  describe '#timeout' do
    before do
      allow(throttler).to receive(:monotonic_now).and_return(0)
      max_messages.times { throttler.filter!(['msg']) }
    end

    it { expect(throttler.timeout).to eq(100) }
  end
end

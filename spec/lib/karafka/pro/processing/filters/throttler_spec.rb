# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:throttler) { described_class.new(max_messages, interval) }

  let(:max_messages) { 10 }
  let(:interval) { 100 }

  describe '#apply!' do
    context 'when no messages are throttled' do
      let(:messages) { ['message'] }

      before { throttler.apply!(messages) }

      it { expect(throttler.applied?).to be(false) }
      it { expect(throttler.action).to eq(:skip) }
    end

    context 'when some messages are throttled' do
      let(:throttled_message) { 'throttled_message' }
      let(:messages) { ['message', throttled_message] }

      before do
        allow(throttler).to receive(:monotonic_now).and_return(0)
        max_messages.times { throttler.apply!(['msg']) }
      end

      it 'sets #applied? to true' do
        throttler.apply!(messages)
        expect(throttler.applied?).to be(true)
        expect(throttler.action).to eq(:pause)
      end
    end

    context 'when some messages were throttled but expired' do
      let(:throttled_message) { 'throttled_message' }
      let(:interval) { 100 }
      let(:messages) { ['message', throttled_message] }

      before do
        max_messages.times { throttler.apply!(['msg']) }
        throttler.apply!(messages)
        sleep(0.11)
      end

      it { expect(throttler.applied?).to be(true) }
      it { expect(throttler.action).to eq(:seek) }
      it { expect(throttler.cursor).to eq('message') }
    end

    context 'when we hit the limit on one go but do not go beyond' do
      let(:messages) { Array.new(max_messages) { 'msg' } }

      before { allow(throttler).to receive(:monotonic_now).and_return(0) }

      it 'sets #applied? to false' do
        throttler.apply!(messages)
        expect(throttler.applied?).to be(false)
      end

      it 'expect not to remove last message when we reached limit' do
        throttler.apply!(messages)
        expect(messages.count).to eq(max_messages)
      end
    end

    context 'when we hit the limit on one go and go beyond' do
      let(:messages) { Array.new(max_messages + 1) { 'msg' } }

      before { allow(throttler).to receive(:monotonic_now).and_return(0) }

      it 'sets #applied? to true' do
        throttler.apply!(messages)
        expect(throttler.applied?).to be(true)
      end

      it 'expect not to remove last message when we reached limit' do
        throttler.apply!(messages)
        expect(messages.count).to eq(max_messages)
      end
    end
  end

  describe '#timeout' do
    before do
      allow(throttler).to receive(:monotonic_now).and_return(0)
      max_messages.times { throttler.apply!(['msg']) }
    end

    it { expect(throttler.timeout).to eq(100) }
  end
end

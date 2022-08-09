# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new(200) }

  context 'when we still have time after 2 ms and it is first attempt' do
    before do
      tracker.start
      sleep 0.002
      tracker.checkpoint
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(true) }
    # Compensate for slow CI
    it { expect(tracker.remaining).to  be_within(5).of(197) }
    it { expect(tracker.attempts).to eq(1) }

    context 'when needing to backoff' do
      before do
        allow(tracker).to receive(:sleep)
        tracker.backoff
      end

      it { expect(tracker).to have_received(:sleep).with(0.1) }
    end
  end

  context 'when we no longer have time after first attempt' do
    before do
      tracker.start
      sleep 0.2
      tracker.checkpoint
    end

    it { expect(tracker.exceeded?).to eq(true) }
    it { expect(tracker.retryable?).to eq(false) }
    it { expect(tracker.remaining).to be_within(1).of(-1) }
    it { expect(tracker.attempts).to eq(1) }

    context 'when needing to backoff' do
      before do
        allow(tracker).to receive(:sleep)
        tracker.backoff
      end

      it { expect(tracker).to have_received(:sleep).with(0.1) }
    end
  end

  context 'when we have several attempts each within time range but exceeding retry' do
    before do
      3.times do
        tracker.start
        sleep 0.005
        tracker.checkpoint
      end
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(false) }
    it { expect(tracker.remaining).to be_within(10).of(185) }
    it { expect(tracker.attempts).to eq(3) }

    context 'when needing to backoff' do
      before do
        allow(tracker).to receive(:sleep)
        tracker.backoff
      end

      it { expect(tracker).to have_received(:sleep).with(0.3) }
    end
  end

  context 'when we do not have enough time to backoff' do
    before do
      tracker.start

      sleep 0.1995

      tracker.checkpoint
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(false) }
    it { expect(tracker.remaining).to be_within(1).of(0) }
    it { expect(tracker.attempts).to eq(1) }

    context 'when needing to backoff' do
      before do
        allow(tracker).to receive(:sleep)
        tracker.backoff
      end

      it { expect(tracker).to have_received(:sleep).with(0.1) }
    end
  end
end

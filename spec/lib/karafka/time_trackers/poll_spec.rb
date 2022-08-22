# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.new(1_000) }

  context 'when we still have time after 2 ms and it is first attempt' do
    before do
      allow(::Process).to receive(:clock_gettime).and_return(1, 1.002)

      tracker.start
      tracker.checkpoint
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(true) }
    # Compensate for slow CI
    it { expect(tracker.remaining).to  be_within(50).of(997) }
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
      allow(::Process).to receive(:clock_gettime).and_return(1, 2)

      tracker.start
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
      allow(::Process).to receive(:clock_gettime).and_return(1, 1.25, 1.5, 1.75, 2.0, 2.25)

      3.times do
        tracker.start
        tracker.checkpoint
      end
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(false) }
    it { expect(tracker.remaining).to be_within(50).of(250) }
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
      allow(::Process).to receive(:clock_gettime).and_return(1, 1.995)

      tracker.start
      tracker.checkpoint
    end

    it { expect(tracker.exceeded?).to eq(false) }
    it { expect(tracker.retryable?).to eq(false) }
    it { expect(tracker.remaining).to be_within(4).of(5) }
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

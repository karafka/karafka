# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) do
    described_class.new(
      timeout: timeout,
      max_timeout: max_timeout,
      exponential_backoff: exponential_backoff
    )
  end

  before do
    # We use different clock in 3.2 that does not require multiplication
    # @see `::Karafka::Core::Helpers::Time` for more details
    normalized = RUBY_VERSION >= '3.2' ? times.map { |time| time * 1_000 } : times

    allow(::Process).to receive(:clock_gettime).and_return(*normalized)
  end

  let(:times) { [0, 0] }

  context 'when max timeout not defined and no exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { nil }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end

    context 'when immediately after paused and incremented' do
      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when not paused over timeout' do
      let(:times) { [0.763, 0.764] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout several times' do
      before do
        5.times do
          tracker.pause
          tracker.increment
          tracker.resume
        end
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(5) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end
  end

  context 'when max timeout defined and no exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { 5 }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end

    context 'when immediately after paused' do
      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      # 1 ms of a difference
      let(:times) { [0.763, 0.764] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 0.769] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 0.769] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 0.769] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end
  end

  context 'when max timeout defined and exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { 100 }
    let(:exponential_backoff) { true }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end

    context 'when immediately after paused' do
      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      let(:times) { [0.763, 0.764] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.increment
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end
  end

  context 'when we define a custom manual pause time' do
    let(:timeout) { 5000 }
    let(:max_timeout) { 5000 }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end

    context 'when immediately after paused' do
      before do
        tracker.pause(1)
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused and manually expired' do
      before do
        tracker.pause(1_000)
        tracker.increment
        tracker.expire
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      let(:times) { [0.763, 0.764] }

      before do
        tracker.pause(2)
        tracker.increment
      end

      it { expect(tracker.expired?).to be(false) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause(1)
        tracker.increment
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(true) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause(1)
        tracker.increment
        tracker.resume
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause(1)
        tracker.increment
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to be(true) }
      it { expect(tracker.paused?).to be(false) }
      it { expect(tracker.attempt).to eq(0) }
    end
  end
end

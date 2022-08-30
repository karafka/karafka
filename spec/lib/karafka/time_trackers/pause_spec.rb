# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) do
    described_class.new(
      timeout: timeout,
      max_timeout: max_timeout,
      exponential_backoff: exponential_backoff
    )
  end

  before { allow(::Process).to receive(:clock_gettime).and_return(*times) }

  let(:times) { [0, 0] }

  context 'when max timeout not defined and no exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { nil }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end

    context 'when immediately after paused' do
      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when not paused over timeout' do
      let(:times) { [0.763, 0.764] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout' do
      let(:times) { [0.763, 1.764] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout several times' do
      before do
        5.times do
          tracker.pause
          tracker.resume
        end
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(5) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.resume
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end
  end

  context 'when max timeout defined and no exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { 5 }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end

    context 'when immediately after paused' do
      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      # 1 ms of a difference
      let(:times) { [0.763, 0.764] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 0.769] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 0.769] }

      before do
        tracker.pause
        tracker.resume
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 0.769] }

      before do
        tracker.pause
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end
  end

  context 'when max timeout defined and exponential backoff' do
    let(:timeout) { 10 }
    let(:max_timeout) { 100 }
    let(:exponential_backoff) { true }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end

    context 'when immediately after paused' do
      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      let(:times) { [0.763, 0.764] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 1.764] }

      before { tracker.pause }

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.resume
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end
  end

  context 'when we define a custom manual pause time' do
    let(:timeout) { 5000 }
    let(:max_timeout) { 5000 }
    let(:exponential_backoff) { false }

    context 'when pause tracker is created' do
      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end

    context 'when immediately after paused' do
      before { tracker.pause(1) }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused and manually expired' do
      before do
        tracker.pause(1_000)
        tracker.expire
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when not paused over timeout nor max timeout' do
      let(:times) { [0.763, 0.764] }

      before { tracker.pause(2) }

      it { expect(tracker.expired?).to eq(false) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over max timeout' do
      let(:times) { [0.763, 1.764] }

      before { tracker.pause(1) }

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(true) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout and resumed' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause(1)
        tracker.resume
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(1) }
    end

    context 'when paused over timeout, resumed and reset' do
      let(:times) { [0.763, 1.764] }

      before do
        tracker.pause(1)
        tracker.resume
        tracker.reset
      end

      it { expect(tracker.expired?).to eq(true) }
      it { expect(tracker.paused?).to eq(false) }
      it { expect(tracker.count).to eq(0) }
    end
  end
end

# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }
  let(:message) { build(:messages_message) }

  describe '#pause_tracker' do
    it { expect(coordinator.pause_tracker).to eq(pause_tracker) }
  end

  describe '#start' do
    before { coordinator.start([message]) }

    it { expect(coordinator.success?).to eq(true) }
    it { expect(coordinator.revoked?).to eq(false) }
    it { expect(coordinator.manual_pause?).to eq(false) }

    context 'when previous coordinator usage had a manual pause' do
      before do
        pause_tracker.pause
        coordinator.manual_pause
        coordinator.start([message])
      end

      it { expect(coordinator.success?).to eq(true) }
      it { expect(coordinator.revoked?).to eq(false) }
      it { expect(coordinator.manual_pause?).to eq(false) }
    end
  end

  describe '#increment' do
    before { coordinator.increment }

    it { expect(coordinator.success?).to eq(false) }
    it { expect(coordinator.revoked?).to eq(false) }
  end

  describe '#decrement' do
    context 'when we would go below zero jobs' do
      it 'expect to raise error' do
        expected_error = Karafka::Errors::InvalidCoordinatorStateError
        expect { coordinator.decrement }.to raise_error(expected_error)
      end
    end

    context 'when decrementing from regular jobs count to zero' do
      before do
        coordinator.increment
        coordinator.decrement
      end

      it { expect(coordinator.success?).to eq(true) }
      it { expect(coordinator.revoked?).to eq(false) }
    end

    context 'when decrementing from regular jobs count not to zero' do
      before do
        coordinator.increment
        coordinator.increment
        coordinator.decrement
      end

      it { expect(coordinator.success?).to eq(false) }
      it { expect(coordinator.revoked?).to eq(false) }
    end
  end

  describe '#consumption' do
    it { expect(coordinator.consumption(self)).to be_a(Karafka::Processing::Result) }
  end

  describe '#success?' do
    context 'when there were no jobs' do
      it { expect(coordinator.success?).to eq(true) }
    end

    context 'when there is a job running' do
      before { coordinator.increment }

      it { expect(coordinator.success?).to eq(false) }
    end

    context 'when there are no jobs running and all the finished are success' do
      before { coordinator.consumption(0).success! }

      it { expect(coordinator.success?).to eq(true) }
    end

    context 'when there are jobs running and all the finished are success' do
      before do
        coordinator.consumption(0).success!
        coordinator.increment
      end

      it { expect(coordinator.success?).to eq(false) }
    end

    context 'when there are no jobs running and not all the jobs finished with success' do
      before do
        coordinator.consumption(0).success!
        coordinator.consumption(1).failure!(StandardError.new)
      end

      it { expect(coordinator.success?).to eq(false) }
    end
  end

  describe '#revoke and #revoked?' do
    before { coordinator.revoke }

    it { expect(coordinator.revoked?).to eq(true) }
  end

  describe '#manual_pause and manual_pause?' do
    context 'when there is no pause' do
      it { expect(coordinator.manual_pause?).to eq(false) }
    end

    context 'when there is a system pause' do
      before { pause_tracker.pause }

      it { expect(coordinator.manual_pause?).to eq(false) }
    end

    context 'when there is a manual pause' do
      before do
        pause_tracker.pause
        coordinator.manual_pause
      end

      it { expect(coordinator.manual_pause?).to eq(true) }
    end
  end
end

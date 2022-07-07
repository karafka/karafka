# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }

  describe '#pause_tracker' do
    it { expect(coordinator.pause_tracker).to eq(pause_tracker) }
  end

  describe '#start' do
    before { coordinator.start([]) }

    it { expect(coordinator.success?).to eq(true) }
    it { expect(coordinator.revoked?).to eq(false) }
  end

  describe '#increment' do
    before { coordinator.increment }

    it { expect(coordinator.success?).to eq(false) }
    it { expect(coordinator.revoked?).to eq(false) }
  end

  describe '#decrement' do
    context 'when we would go below zero jobs' do
      it 'expect to raise error' do
        expect { coordinator.decrement }.to raise_error(Karafka::Errors::InvalidCoordinatorState)
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
        coordinator.consumption(1).failure!
      end

      it { expect(coordinator.success?).to eq(false) }
    end
  end

  describe '#revoke and #revoked?' do
    before { coordinator.revoke }

    it { expect(coordinator.revoked?).to eq(true) }
  end
end

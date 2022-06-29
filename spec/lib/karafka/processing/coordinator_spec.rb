# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }

  describe '#pause_tracker' do
    it { expect(coordinator.pause_tracker).to eq(pause_tracker) }
  end

  describe '#start' do
    pending
  end

  describe '#increment' do
    pending
  end

  describe '#decrement' do
    pending
  end

  describe '#consumption' do
    pending
  end

  describe '#success?' do
    pending
  end

  describe '#revoke' do
    pending
  end

  describe '#revoked?' do
    pending
  end
end

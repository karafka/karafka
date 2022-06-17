# frozen_string_literal: true

RSpec.describe_current do
  subject(:coordinator) { described_class.new(pause_tracker) }

  let(:pause_tracker) { build(:time_trackers_pause) }

  describe '#pause_tracker' do
    it { expect(coordinator.pause_tracker).to eq(pause_tracker) }
  end
end

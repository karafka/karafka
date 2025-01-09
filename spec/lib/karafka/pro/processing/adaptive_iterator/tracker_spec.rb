# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:tracker) do
    described_class.new(
      safety_margin,
      last_polled_at,
      max_poll_interval_ms
    )
  end

  let(:safety_margin) { 15 }
  let(:last_polled_at) { described_class.new(1, 1, 1).monotonic_now }
  let(:max_poll_interval_ms) { 10_000 }

  before { tracker }

  describe '#track' do
    context 'when adaptive margin kicks in' do
      it 'yields the block and tracks processing time' do
        expect do |block|
          tracker.track(&block)
        end.to yield_control
      end
    end

    context 'when adaptive margin does not kick in' do
      let(:adaptive_margin) { false }

      it 'yields the block without tracking processing time' do
        expect do |block|
          tracker.track(&block)
        end.to yield_control
      end
    end
  end

  describe '#enough?' do
    context 'when there is enough time left for processing' do
      it 'returns false' do
        sleep(0.01) # Simulate a small delay
        expect(tracker.enough?).to be(false)
      end
    end

    context 'when there is not enough time left considering the safety margin' do
      let(:max_poll_interval_ms) { 550 }

      it 'returns true' do
        sleep(0.5) # Simulate a delay that makes it hit the safety margin
        expect(tracker.enough?).to be(true)
      end
    end

    context 'when adaptive margin kicks in and max processing cost is considered' do
      let(:max_poll_interval_ms) { 700 }

      it 'returns true if the remaining time is less than the max processing cost' do
        tracker.track do
          sleep(0.3) # Simulate a processing delay to set max_processing_cost
        end

        sleep(0.1) # Simulate some more elapsed time
        expect(tracker.enough?).to be(true)
      end

      it 'returns false if there is still enough time considering max processing cost' do
        tracker.track do
          sleep(0.01) # Set a small max processing cost
        end

        sleep(0.01) # Simulate small delay
        expect(tracker.enough?).to be(false)
      end
    end
  end
end

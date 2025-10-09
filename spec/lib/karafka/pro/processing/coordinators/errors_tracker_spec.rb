# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:tracker) { described_class.new(topic, 0) }

  let(:topic) { build(:routing_topic) }

  context 'when there are no errors' do
    it { expect(tracker.to_a).to eq([]) }
    it { expect(tracker.size).to eq(0) }
    it { expect(tracker.empty?).to be(true) }
  end

  context 'when we have 100 elements and want to push another' do
    before do
      100.times { |i| tracker << i }
      tracker << 101
    end

    it 'expect to evict oldest element from tracker errors' do
      expect(tracker.size).to eq(101)
      expect(tracker).not_to include(0)
      expect(tracker).to include(1)
      expect(tracker).to include(101)
    end

    it { expect(tracker.all).to be_a(Array) }

    it 'expect to have the newest as last' do
      expect(tracker.last).to eq(101)
    end

    it 'expect to be empty after clear' do
      tracker.clear
      expect(tracker.empty?).to be(true)
    end
  end

  context 'when using granular counts tracking' do
    let(:error_class_a) { Class.new(StandardError) }
    let(:error_class_b) { Class.new(StandardError) }

    before do
      3.times { tracker << error_class_a.new }
      2.times { tracker << error_class_b.new }
    end

    it 'correctly counts occurrences of each error class' do
      expect(tracker.counts[error_class_a]).to eq(3)
      expect(tracker.counts[error_class_b]).to eq(2)
    end

    it 'maintains counts after clearing errors' do
      tracker.clear
      expect(tracker.counts).to be_empty
      expect(tracker.empty?).to be(true)
    end

    it 'increments counts independently from errors storage limit' do
      200.times { tracker << error_class_a.new }
      expect(tracker.counts[error_class_a]).to eq(203)
      expect(tracker.size).to eq(205)
    end
  end

  describe '#trace_id' do
    it 'generates a unique trace_id on initialization' do
      expect(tracker.trace_id).to be_a(String)
      expect(tracker.trace_id).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end

    it 'generates different trace_ids for different tracker instances' do
      tracker1 = described_class.new(topic, 0)
      tracker2 = described_class.new(topic, 1)

      expect(tracker1.trace_id).not_to eq(tracker2.trace_id)
    end

    it 'updates trace_id when an error is added' do
      original_trace_id = tracker.trace_id

      tracker << StandardError.new('test error')

      expect(tracker.trace_id).not_to eq(original_trace_id)
      expect(tracker.trace_id).to be_a(String)
    end

    it 'generates a new trace_id for each error added' do
      tracker << StandardError.new('first error')
      first_trace_id = tracker.trace_id

      tracker << StandardError.new('second error')
      second_trace_id = tracker.trace_id

      expect(first_trace_id).not_to eq(second_trace_id)
    end

    it 'maintains trace_id when accessing other methods' do
      tracker << StandardError.new('test error')
      trace_id_before = tracker.trace_id

      # Access various methods that shouldn't change trace_id
      tracker.size
      tracker.empty?
      tracker.last
      tracker.all
      tracker.each { |_| nil }

      expect(tracker.trace_id).to eq(trace_id_before)
    end

    it 'does not change trace_id when clearing errors' do
      tracker << StandardError.new('test error')
      trace_id_before_clear = tracker.trace_id

      tracker.clear

      expect(tracker.trace_id).to eq(trace_id_before_clear)
    end
  end
end

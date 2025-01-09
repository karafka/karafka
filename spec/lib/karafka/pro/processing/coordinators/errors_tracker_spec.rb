# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:tracker) { described_class.new }

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

    it 'expect to evict oldest element' do
      expect(tracker.size).to eq(100)
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
end

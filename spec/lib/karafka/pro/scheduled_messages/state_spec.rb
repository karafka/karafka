# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  describe '#initialize' do
    it 'initializes with a nil state' do
      state = described_class.new
      expect(state.fresh?).to be(true)
      expect(state.loaded?).to be(false)
      expect(state.to_s).to eq('fresh')
    end

    it 'initializes with false state' do
      state = described_class.new(false)
      expect(state.fresh?).to be(false)
      expect(state.loaded?).to be(false)
      expect(state.to_s).to eq('loading')
    end

    it 'initializes with true state' do
      state = described_class.new(true)
      expect(state.fresh?).to be(false)
      expect(state.loaded?).to be(true)
      expect(state.to_s).to eq('loaded')
    end
  end

  describe '#fresh?' do
    it 'returns true when the state is fresh' do
      state = described_class.new
      expect(state.fresh?).to be(true)
    end

    it 'returns false when the state is not fresh' do
      state = described_class.new(false)
      expect(state.fresh?).to be(false)
    end
  end

  describe '#loaded?' do
    it 'returns false when the state is fresh' do
      state = described_class.new
      expect(state.loaded?).to be(false)
    end

    it 'returns false when the state is loading' do
      state = described_class.new(false)
      expect(state.loaded?).to be(false)
    end

    it 'returns true when the state is loaded' do
      state = described_class.new(true)
      expect(state.loaded?).to be(true)
    end
  end

  describe '#loaded!' do
    it 'marks the state as loaded' do
      state = described_class.new
      state.loaded!
      expect(state.loaded?).to be(true)
      expect(state.to_s).to eq('loaded')
    end

    it 'changes a previously loaded state' do
      state = described_class.new(true)
      state.loaded!
      expect(state.loaded?).to be(true)
      expect(state.to_s).to eq('loaded')
    end
  end

  describe '#to_s' do
    it 'returns "fresh" when the state is fresh' do
      state = described_class.new
      expect(state.to_s).to eq('fresh')
    end

    it 'returns "loading" when the state is loading' do
      state = described_class.new(false)
      expect(state.to_s).to eq('loading')
    end

    it 'returns "loaded" when the state is loaded' do
      state = described_class.new(true)
      expect(state.to_s).to eq('loaded')
    end
  end
end

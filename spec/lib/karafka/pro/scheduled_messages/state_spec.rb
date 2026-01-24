# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  describe '#initialize' do
    it 'initializes with fresh state by default' do
      state = described_class.new
      expect(state.fresh?).to be(true)
      expect(state.loading?).to be(false)
      expect(state.loaded?).to be(false)
      expect(state.stopped?).to be(false)
      expect(state.to_s).to eq('fresh')
    end
  end

  describe 'state predicate methods' do
    let(:state) { described_class.new }

    describe '#fresh?' do
      it 'returns true when the state is fresh' do
        expect(state.fresh?).to be(true)
      end

      it 'returns false when the state is not fresh' do
        state.loading!
        expect(state.fresh?).to be(false)
      end
    end

    describe '#loading?' do
      it 'returns false when the state is fresh' do
        expect(state.loading?).to be(false)
      end

      it 'returns true when the state is loading' do
        state.loading!
        expect(state.loading?).to be(true)
      end
    end

    describe '#loaded?' do
      it 'returns false when the state is fresh' do
        expect(state.loaded?).to be(false)
      end

      it 'returns false when the state is loading' do
        state.loading!
        expect(state.loaded?).to be(false)
      end

      it 'returns true when the state is loaded' do
        state.loaded!
        expect(state.loaded?).to be(true)
      end
    end

    describe '#stopped?' do
      it 'returns false when the state is fresh' do
        expect(state.stopped?).to be(false)
      end

      it 'returns true when the state is stopped' do
        state.stopped!
        expect(state.stopped?).to be(true)
      end
    end
  end

  describe 'state transition methods' do
    let(:state) { described_class.new }

    describe '#fresh!' do
      it 'sets the state to fresh' do
        state.loaded!
        state.fresh!
        expect(state.fresh?).to be(true)
        expect(state.to_s).to eq('fresh')
      end
    end

    describe '#loading!' do
      it 'sets the state to loading' do
        state.loading!
        expect(state.loading?).to be(true)
        expect(state.fresh?).to be(false)
        expect(state.to_s).to eq('loading')
      end
    end

    describe '#loaded!' do
      it 'sets the state to loaded from fresh' do
        state.loaded!
        expect(state.loaded?).to be(true)
        expect(state.fresh?).to be(false)
        expect(state.to_s).to eq('loaded')
      end

      it 'sets the state to loaded from loading' do
        state.loading!
        state.loaded!
        expect(state.loaded?).to be(true)
        expect(state.loading?).to be(false)
        expect(state.to_s).to eq('loaded')
      end
    end

    describe '#stopped!' do
      it 'sets the state to stopped' do
        state.loaded!
        state.stopped!
        expect(state.stopped?).to be(true)
        expect(state.loaded?).to be(false)
        expect(state.to_s).to eq('stopped')
      end
    end
  end

  describe '#to_s' do
    let(:state) { described_class.new }

    it 'returns "fresh" when the state is fresh' do
      expect(state.to_s).to eq('fresh')
    end

    it 'returns "loading" when the state is loading' do
      state.loading!
      expect(state.to_s).to eq('loading')
    end

    it 'returns "loaded" when the state is loaded' do
      state.loaded!
      expect(state.to_s).to eq('loaded')
    end

    it 'returns "stopped" when the state is stopped' do
      state.stopped!
      expect(state.to_s).to eq('stopped')
    end
  end

  describe 'state transitions' do
    let(:state) { described_class.new }

    it 'allows transitioning through typical flow' do
      # Start fresh
      expect(state.fresh?).to be(true)

      state.loading!
      expect(state.loading?).to be(true)
      expect(state.fresh?).to be(false)

      state.loaded!
      expect(state.loaded?).to be(true)
      expect(state.loading?).to be(false)

      state.stopped!
      expect(state.stopped?).to be(true)
      expect(state.loaded?).to be(false)
    end
  end
end

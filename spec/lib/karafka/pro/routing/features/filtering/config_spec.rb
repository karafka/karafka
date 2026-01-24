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
  subject(:config) { described_class.new(factories: factories) }

  describe '#active?' do
    context 'when there are factories' do
      let(:factories) { [1] }

      it { expect(config.active?).to be(true) }
    end

    context 'when there are no factories' do
      let(:factories) { [] }

      it { expect(config.active?).to be(false) }
    end
  end

  describe '#filters' do
    context 'when no factories are registered' do
      let(:factories) { [] }

      it { expect(config.filters).to eq([]) }
    end

    context 'when factories are registered' do
      let(:factories) do
        [
          -> { 1 },
          -> { 2 }
        ]
      end

      it 'expect to use them to build' do
        expect(config.filters).to eq([1, 2])
      end
    end
  end

  describe '#to_h' do
    let(:factories) { [1] }

    it { expect(config.to_h[:factories]).to eq(factories) }
    it { expect(config.to_h[:active]).to be(true) }
  end
end

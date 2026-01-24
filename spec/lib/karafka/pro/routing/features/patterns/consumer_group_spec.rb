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
  subject(:cg) { build(:routing_consumer_group) }

  let(:adding_pattern) do
    cg.public_send(:pattern=, /test/) do
      consumer Class.new
    end
  end

  it { expect(cg.patterns).to be_empty }

  describe '#patterns and #pattern=' do
    it do
      expect { adding_pattern }.to change(cg.patterns, :size).from(0).to(1)
    end

    it do
      expect { adding_pattern }.to change(cg.topics, :size).from(0).to(1)
    end

    it do
      adding_pattern

      expect(cg.topics.last.name).to eq(cg.patterns.last.name)
    end
  end

  describe '#to_h' do
    context 'when no patterns' do
      it { expect(cg.to_h[:patterns]).to eq([]) }
    end

    context 'when there are patterns' do
      let(:expected_hash) { { regexp: /test/, name: cg.topics.last.name, regexp_string: '^test' } }

      before { adding_pattern }

      it 'expect to add patterns to hash' do
        expect(cg.to_h[:patterns]).to eq([expected_hash])
      end
    end
  end
end

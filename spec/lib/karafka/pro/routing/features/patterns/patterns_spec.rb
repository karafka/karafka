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
  subject(:patterns) { described_class.new([]) }

  let(:pattern_class) { Karafka::Pro::Routing::Features::Patterns::Pattern }

  describe '#find' do
    let(:topic_name) { 'test_topic' }
    let(:matching_pattern) { pattern_class.new(nil, /test_/, -> {}) }
    let(:non_matching_pattern) { pattern_class.new(nil, /not_matching_/, -> {}) }

    before do
      patterns << non_matching_pattern
      patterns << matching_pattern
    end

    it 'expects to find a pattern matching the topic name' do
      expect(patterns.find(topic_name)).to eq(matching_pattern)
    end

    context 'when multiple patterns match' do
      let(:another_matching_pattern) { pattern_class.new(nil, /_topic/, -> {}) }

      before { patterns << another_matching_pattern }

      it 'expects to return the first matching pattern' do
        expect(patterns.find(topic_name)).to eq(matching_pattern)
      end
    end

    context 'when no pattern matches' do
      let(:topic_name) { 'unmatched_topic' }

      it { expect(patterns.find(topic_name)).to be_nil }
    end
  end
end

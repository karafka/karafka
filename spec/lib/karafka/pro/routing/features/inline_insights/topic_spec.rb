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
  subject(:topic) { build(:routing_topic) }

  describe '#inline_insights' do
    context 'when we use inline_insights without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.inline_insights.active?).to be(false)
      end
    end

    context 'when we use inline_insights with a true' do
      it 'expect to use proper active status' do
        topic.inline_insights(true)
        expect(topic.inline_insights.active?).to be(true)
      end
    end

    context 'when we use inline_insights via setting only required' do
      it 'expect to use proper active status' do
        topic.inline_insights(required: true)
        expect(topic.inline_insights.active?).to be(true)
        expect(topic.inline_insights.required?).to be(true)
      end
    end

    context 'when we use inline_insights multiple times with different values' do
      before do
        topic.inline_insights(true)
        topic.inline_insights(false)
      end

      it 'expect to use proper active status' do
        expect(topic.inline_insights.active?).to be(true)
      end

      it 'expect not to add any filters' do
        expect(topic.filter.factories.size).to eq(0)
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:inline_insights]).to eq(topic.inline_insights.to_h) }
  end
end

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
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#offset_metadata' do
    context 'when we use offset_metadata without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.offset_metadata.active?).to be(true)
        expect(topic.offset_metadata.deserializer).not_to be_nil
      end
    end

    context 'when we use offset_metadata multiple times with different values' do
      it 'expect to use proper active status' do
        topic.offset_metadata(deserializer: 1)
        topic.offset_metadata(deserializer: 2)
        expect(topic.offset_metadata.active?).to be(true)
        expect(topic.offset_metadata.deserializer).to eq(1)
      end
    end
  end

  describe '#offset_metadata?' do
    it { expect(topic.offset_metadata?).to be(true) }
  end

  describe '#to_h' do
    it { expect(topic.to_h[:offset_metadata]).to eq(topic.offset_metadata.to_h) }
  end
end

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
  let(:consumer) { Class.new { include Karafka::Pro::Processing::OffsetMetadata::Consumer }.new }
  let(:topic) { build(:routing_topic) }
  let(:partition) { 5 }
  let(:fetcher) { Karafka::Pro::Processing::OffsetMetadata::Fetcher }

  before do
    allow(consumer).to receive_messages(
      topic: topic,
      partition: partition
    )
  end

  describe '#offset_metadata' do
    context 'when assignment is revoked' do
      before { allow(consumer).to receive(:revoked?).and_return(true) }

      it { expect(consumer.offset_metadata).to be(false) }
    end

    context 'when assignment is active' do
      let(:result) { rand }

      before do
        allow(consumer).to receive(:revoked?).and_return(false)
        allow(fetcher).to receive(:find).and_return(result)
      end

      it 'expect to reach out to fetcher' do
        expect(consumer.offset_metadata).to eq(result)
        expect(fetcher).to have_received(:find).with(topic, partition, cache: true)
      end
    end
  end

  describe '#committed_offset_metadata' do
    it do
      expect(consumer.method(:offset_metadata)).to eq(consumer.method(:committed_offset_metadata))
    end
  end
end

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
  describe '.schedule' do
    let(:proxy_args) { { key1: 'value1', key2: 'value2' } }
    let(:expected_result) { { wrapped_message: 'message' } }

    before do
      allow(Karafka::Pro::ScheduledMessages::Proxy)
        .to receive(:schedule)
        .with(**proxy_args)
        .and_return(expected_result)
    end

    it 'delegates to Proxy.schedule with the correct arguments' do
      result = described_class.schedule(**proxy_args)
      expect(Karafka::Pro::ScheduledMessages::Proxy)
        .to have_received(:schedule).with(**proxy_args)
      expect(result).to eq(expected_result)
    end

    it 'returns the result from Proxy.schedule' do
      result = described_class.schedule(**proxy_args)
      expect(result).to eq(expected_result)
    end

    context 'when Proxy.schedule raises an error' do
      before do
        allow(Karafka::Pro::ScheduledMessages::Proxy)
          .to receive(:schedule)
          .and_raise(StandardError, 'Proxy error')
      end

      it 'raises the same error' do
        expect { described_class.schedule(**proxy_args) }
          .to raise_error(StandardError, 'Proxy error')
      end
    end
  end

  describe '.cancel' do
    let(:proxy_args) { { key1: 'value1', key2: 'value2' } }
    let(:expected_result) { { wrapped_message: 'message' } }

    before do
      allow(Karafka::Pro::ScheduledMessages::Proxy)
        .to receive(:cancel)
        .with(**proxy_args)
        .and_return(expected_result)
    end

    it 'delegates to Proxy.cancel with the correct arguments' do
      result = described_class.cancel(**proxy_args)
      expect(Karafka::Pro::ScheduledMessages::Proxy)
        .to have_received(:cancel).with(**proxy_args)
      expect(result).to eq(expected_result)
    end

    it 'returns the result from Proxy.cancel' do
      result = described_class.cancel(**proxy_args)
      expect(result).to eq(expected_result)
    end

    context 'when Proxy.cancel raises an error' do
      before do
        allow(Karafka::Pro::ScheduledMessages::Proxy)
          .to receive(:cancel)
          .and_raise(StandardError, 'Proxy error')
      end

      it 'raises the same error' do
        expect { described_class.cancel(**proxy_args) }
          .to raise_error(StandardError, 'Proxy error')
      end
    end
  end
end

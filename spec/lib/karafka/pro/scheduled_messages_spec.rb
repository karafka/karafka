# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

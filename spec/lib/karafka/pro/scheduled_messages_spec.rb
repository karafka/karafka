# frozen_string_literal: true

RSpec.describe_current do
  describe '.proxy' do
    let(:proxy_args) { { key1: 'value1', key2: 'value2' } }
    let(:expected_result) { { wrapped_message: 'message' } }

    before do
      allow(Karafka::Pro::ScheduledMessages::Proxy)
        .to receive(:call)
        .with(**proxy_args)
        .and_return(expected_result)
    end

    it 'delegates to Proxy.call with the correct arguments' do
      result = described_class.proxy(**proxy_args)
      expect(Karafka::Pro::ScheduledMessages::Proxy).to have_received(:call).with(**proxy_args)
      expect(result).to eq(expected_result)
    end

    it 'returns the result from Proxy.call' do
      result = described_class.proxy(**proxy_args)
      expect(result).to eq(expected_result)
    end

    context 'when Proxy.call raises an error' do
      before do
        allow(Karafka::Pro::ScheduledMessages::Proxy)
          .to receive(:call)
          .and_raise(StandardError, 'Proxy error')
      end

      it 'raises the same error' do
        expect { described_class.proxy(**proxy_args) }.to raise_error(StandardError, 'Proxy error')
      end
    end
  end
end

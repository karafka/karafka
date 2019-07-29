# frozen_string_literal: true

RSpec.describe Karafka::Params::Params do
  let(:base_params_class) { described_class }
  let(:headers) { { message_type: 'test' } }

  describe 'instance methods' do
    subject(:params) { base_params_class.send(:new) }

    describe '#deserialize!' do
      context 'when params are already deserialized' do
        before { params['deserialized'] = true }

        it 'expect not to deserialize again and return self' do
          expect(params).not_to receive(:deserialize)
          expect(params).not_to receive(:merge!)
          expect(params.deserialize!).to eq params
        end
      end

      context 'when params were not yet deserializeds' do
        let(:payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          params['payload'] = payload
          params['headers'] = headers

          allow(params)
            .to receive(:deserialize)
            .and_return(deserialized_payload)

          params.deserialize!
        end

        it 'expect to merge with deserialized data that is under payload key' do
          expect(params.payload).to eq deserialized_payload
        end

        it 'expect to mark as deserialized' do
          expect(params.deserialize!['deserialized']).to eq true
        end
      end

      context 'when deserialization error occurs' do
        let(:payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          params['payload'] = payload
          params['headers'] = headers

          allow(params)
            .to receive(:deserialize)
            .and_raise(Karafka::Errors::DeserializationError)

          begin
            params.deserialize!
          rescue Karafka::Errors::DeserializationError
            false
          end
        end

        it 'expect to keep the raw payload within the params hash' do
          expect(params['payload']).to eq(payload)
        end
      end
    end

    describe '#deserialize' do
      let(:deserializer) { double }
      let(:payload) { double }

      before do
        params['deserializer'] = deserializer
        params['headers'] = headers
      end

      context 'when we are able to successfully deserialize' do
        let(:deserialized_payload) { { rand => rand } }

        before do
          allow(deserializer)
            .to receive(:call)
            .with(params)
            .and_return(deserialized_payload)
        end

        it 'expect to return payload in a message key' do
          expect(params.send(:deserialize)).to eq deserialized_payload
        end
      end

      context 'when deserialization fails' do
        let(:expected_error) { ::Karafka::Errors::DeserializationError }
        let(:instrument_args) do
          [
            'params.params.deserialize',
            caller: params
          ]
        end
        let(:instrument_error_args) do
          [
            'params.params.deserialize.error',
            caller: params,
            error: ::Karafka::Errors::DeserializationError
          ]
        end

        before do
          allow(deserializer)
            .to receive(:call)
            .with(params)
            .and_raise(::Karafka::Errors::DeserializationError)
        end

        it 'expect to monitor and reraise' do
          expect(Karafka.monitor).to receive(:instrument).with(*instrument_args).and_yield
          expect(Karafka.monitor).to receive(:instrument).with(*instrument_error_args)
          expect { params.send(:deserialize) }.to raise_error(expected_error)
        end
      end
    end

    %w[
      topic
      partition
      offset
      headers
      key
      create_time
    ].each do |key|
      describe "\##{key}" do
        let(:payload) { rand }

        before { params[key] = payload }

        it { expect(params.public_send(key)).to eq params[key] }
      end
    end
  end
end

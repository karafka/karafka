# frozen_string_literal: true

RSpec.describe Karafka::Params::Params do
  let(:base_params_class) { described_class }

  describe 'instance methods' do
    subject(:params) { base_params_class.send(:new) }

    describe '#parse!' do
      context 'when params are already parsed' do
        before { params['parsed'] = true }

        it 'expect not to parse again and return self' do
          expect(params).not_to receive(:parse)
          expect(params).not_to receive(:merge!)
          expect(params.parse!).to eq params
        end
      end

      context 'when params were not yet parseds' do
        let(:value) { double }
        let(:parsed_value) { { double => double } }

        before do
          params['value'] = value

          allow(params)
            .to receive(:parse)
            .with(value)
            .and_return(parsed_value)

          params.parse!
        end

        it 'expect to merge with parsed stuff that is under value key and remove this key' do
          expect(params.value).to eq parsed_value
        end

        it 'expect to mark as parsed' do
          expect(params.parse!['parsed']).to eq true
        end
      end

      context 'when parsing error occurs' do
        let(:value) { double }
        let(:parsed_value) { { double => double } }

        before do
          params['value'] = value

          allow(params)
            .to receive(:parse)
            .and_raise(Karafka::Errors::ParserError)
        end

        it 'expect to keep the raw value within the params hash' do
          params.parse! rescue false
          expect(params['value']).to eq(value)
        end
      end
    end

    describe '#parse' do
      let(:parser) { double }
      let(:value) { double }

      before do
        params['parser'] = parser
      end

      context 'when we are able to successfully parse' do
        let(:parsed_value) { { rand => rand } }

        before do
          allow(parser)
            .to receive(:parse)
            .with(value)
            .and_return(parsed_value)
        end

        it 'expect to return value in a message key' do
          expect(params.send(:parse, value)).to eq parsed_value
        end
      end

      context 'when parsing fails' do
        let(:instrument_args) do
          [
            'params.params.parse',
            caller: params
          ]
        end
        let(:instrument_error_args) do
          [
            'params.params.parse.error',
            caller: params,
            error: ::Karafka::Errors::ParserError
          ]
        end

        before do
          allow(parser)
            .to receive(:parse)
            .with(value)
            .and_raise(::Karafka::Errors::ParserError)
        end

        it 'expect to monitor and reraise' do
          expect(Karafka.monitor).to receive(:instrument).with(*instrument_args).and_yield
          expect(Karafka.monitor).to receive(:instrument).with(*instrument_error_args)
          expect { params.send(:parse, value) }.to raise_error(::Karafka::Errors::ParserError)
        end
      end
    end

    %w[
      topic
      partition
      offset
      key
      create_time
    ].each do |key|
      describe "\##{key}" do
        let(:value) { rand }

        before { params[key] = value }

        it { expect(params.public_send(key)).to eq params[key] }
      end
    end
  end
end

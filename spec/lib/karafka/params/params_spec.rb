# frozen_string_literal: true

RSpec.describe Karafka::Params::Params do
  let(:base_params_class) { described_class }

  describe 'class methods' do
    subject(:params_class) { base_params_class }

    describe '#build' do
      let(:parser) { Karafka::Parsers::Json }

      context 'when we build from a hash' do
        let(:message) { { rand => rand, 'parser' => rand.to_s } }
        let(:params) { params_class.build(message, parser) }

        it 'expect to build based on a message' do
          expect(params).to eq message.merge('parser' => parser)
        end

        it 'expect not to overwrite parser' do
          expect(params['parser']).to eq parser
        end
      end

      context 'when we build based on Kafka::FetchedMessage' do
        let(:topic) { rand.to_s }
        let(:value) { rand.to_s }
        let(:key) { nil }
        let(:offset) { rand(1000) }
        let(:partition) { rand(100) }
        let(:create_time) { Time.now }
        let(:params_attributes) do
          {
            parser: parser,
            receive_time: Time.now,
            value: value,
            offset: offset,
            partition: partition,
            key: key,
            topic: topic,
            create_time: create_time
          }
        end
        let(:message) do
          Kafka::FetchedMessage.new(
            message: OpenStruct.new(
              value: value,
              key: key,
              offset: offset,
              create_time: create_time
            ),
            topic: topic,
            partition: partition
          )
        end

        it 'expect to build with additional values and value' do
          Timecop.freeze do
            # We symbolize keys as hash with indifferent access will compare with
            # a hash against string keys. This does not matter when accessing via
            # string or symbols for single arguments
            params = params_class.build(message, parser)
            expect(params.symbolize_keys).to eq params_attributes
          end
        end
      end
    end
  end

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

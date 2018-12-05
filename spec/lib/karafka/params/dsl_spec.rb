# frozen_string_literal: true

RSpec.describe Karafka::Params::Dsl do
  [
    Hash,
    HashWithIndifferentAccess
  ].each do |base_for_params|
    context "when #{base_for_params} acts as a base for params" do
      let(:base_params_class) do
        inclusion = described_class

        ClassBuilder.inherit(base_for_params) do
          include inclusion
        end
      end

      describe 'class methods' do
        subject(:params_class) { base_params_class }

        describe '#build' do
          let(:parser) { Karafka::Parsers::Json }

          context 'when we build from a hash' do
            let(:message) { { rand => rand } }

            it 'expect to build based on a message' do
              params = params_class.build(message, parser)
              expect(params.symbolize_keys).to eq message.merge(parser: parser)
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

        describe '#retrieve!' do
          context 'when params are already parsed' do
            before { params['parsed'] = true }

            it 'expect not to parse again and return self' do
              expect(params).not_to receive(:parse)
              expect(params).not_to receive(:merge!)
              expect(params.retrieve!).to eq params
            end
          end

          context 'when params were not yet parsed and value does not contain same keys' do
            let(:value) { double }
            let(:parsed_value) { { double => double } }

            before do
              params['value'] = value

              allow(params)
                .to receive(:parse)
                .with(value)
                .and_return(parsed_value)
            end

            it 'expect to merge with parsed stuff that is under value key and remove this key' do
              expect(params.retrieve![parsed_value.keys[0]]).to eq parsed_value.values[0]
              expect(params.keys).not_to include :value
            end

            it 'expect to mark as parsed' do
              expect(params.retrieve!['parsed']).to eq true
            end
          end

          context 'when params were not yet parsed and value does contain same keys' do
            let(:value) { double }
            let(:parsed_value) { { 'receive_time' => rand } }

            before do
              params['value'] = value

              allow(params)
                .to receive(:parse)
                .with(value)
                .and_return(parsed_value)
            end

            it 'expect not to overwrite existing keys' do
              params.retrieve!
              expect(params[parsed_value['receive_time']]).not_to eq parsed_value['receive_time']
              expect(params.keys).not_to include 'value'
            end
          end

          context 'when params were not yet parsed and there os a parsing error' do
            let(:value) { double }
            let(:parsed_value) { { 'receive_time' => rand } }

            before do
              params['value'] = value

              allow(params)
                .to receive(:parse)
                .and_raise(Karafka::Errors::ParserError)

              params.retrieve! rescue false
            end

            it 'expect not to remove the original value' do
              expect(params['value']).to eq value
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

        describe '#merge!' do
          subject(:params) do
            instance = base_params_class.new
            base.each { |key, value| instance[key] = value }
            instance
          end

          context 'when string based params merge with string key' do
            let(:initial_value) { rand }
            let(:key) { rand.to_s }
            let(:base) { { key => initial_value } }

            it 'expect to keep initial values' do
              params.send :merge!, key => rand
              expect(params[key]).to eq initial_value
            end
          end

          context 'when string based params merge with symbol key' do
            let(:initial_value) { rand }
            let(:key) { rand.to_s }
            let(:base) { { key => initial_value } }

            it 'expect to keep initial values' do
              params.send :merge!, key.to_sym => rand
              expect(params[key]).to eq initial_value
            end
          end

          context 'when symbol based params merge with symbol key' do
            let(:initial_value) { rand }
            let(:key) { rand.to_s.to_sym }
            let(:base) { { key => initial_value } }

            it 'expect to keep initial values' do
              params.send :merge!, key.to_sym => rand
              expect(params[key]).to eq initial_value
            end
          end

          context 'when symbol based params merge with string key' do
            let(:initial_value) { rand }
            let(:key) { rand.to_s }
            let(:base) { { key.to_s => initial_value } }

            it 'expect to keep initial values' do
              params.send :merge!, key => rand
              expect(params[key]).to eq initial_value
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
  end
end

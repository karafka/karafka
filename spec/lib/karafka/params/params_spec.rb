# frozen_string_literal: true

RSpec.describe Karafka::Params::Params do
  describe 'class methods' do
    subject(:params_class) { described_class }

    describe '#build' do
      let(:parser) { Karafka::Parsers::Json }

      context 'when we build from a hash' do
        let(:message) { { rand => rand } }

        it 'expect to build based on a message' do
          expect(params_class.build(message, parser)).to eq message.merge('parser' => parser)
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
            'parser' => parser,
            'parsed' => false,
            'received_at' => Time.now,
            'value' => value,
            'offset' => offset,
            'partition' => partition,
            'key' => key,
            'topic' => topic,
            'create_time' => create_time
          }
        end
        let(:message) do
          instance_double(
            Kafka::FetchedMessage,
            value: value,
            key: key,
            topic: topic,
            partition: partition,
            offset: offset,
            create_time: create_time
          )
        end

        it 'expect to build with additional values and value' do
          Timecop.freeze do
            expect(params_class.build(message, parser)).to eq params_attributes
          end
        end
      end
    end
  end

  describe 'instance methods' do
    subject(:params) { described_class.send(:new, {}) }

    describe '#retrieve!' do
      context 'when params are already parsed' do
        before do
          params[:parsed] = true
        end

        it 'expect not to parse again and return self' do
          expect(params)
            .not_to receive(:parse)

          expect(params)
            .not_to receive(:merge!)

          expect(params.retrieve!).to eq params
        end
      end

      context 'when params were not yet parsed and value does not contain same keys' do
        let(:value) { double }
        let(:parsed_value) { { double => double } }

        before do
          params[:parsed] = false
          params[:value] = value

          expect(params)
            .to receive(:parse)
            .with(value)
            .and_return(parsed_value)
        end

        it 'expect to merge with parsed stuff that is under value key and remove this key' do
          expect(params.retrieve![parsed_value.keys[0]]).to eq parsed_value.values[0]
          expect(params.keys).not_to include :value
        end
      end

      context 'when params were not yet parsed and value does contain same keys' do
        let(:value) { double }
        let(:parsed_value) { { received_at: rand } }

        before do
          params[:parsed] = false
          params[:value] = value

          expect(params)
            .to receive(:parse)
            .with(value)
            .and_return(parsed_value)
        end

        it 'expect not to overwrite existing keys' do
          params.retrieve!
          expect(params[parsed_value[:received_at]]).not_to eq parsed_value[:received_at]
          expect(params.keys).not_to include :value
        end
      end
    end

    describe '#parse' do
      let(:parser) { double }
      let(:value) { double }

      before do
        params[:parser] = parser
        params[:parsed] = false
      end

      context 'when we are able to successfully parse' do
        let(:parsed_value) { { rand => rand } }

        before do
          expect(parser)
            .to receive(:parse)
            .with(value)
            .and_return(parsed_value)
        end

        it 'expect to mark as parsed and return value in a message key' do
          expect(params.send(:parse, value)).to eq parsed_value
          expect(params[:parsed]).to eq true
        end
      end

      context 'when parsing fails' do
        before do
          expect(parser)
            .to receive(:parse)
            .with(value)
            .and_raise(::Karafka::Errors::ParserError)
        end

        it 'expect to monitor, mark as parsed and reraise' do
          expect(Karafka.monitor)
            .to receive(:notice_error)

          expect { params.send(:parse, value) }.to raise_error(::Karafka::Errors::ParserError)
          expect(params[:parsed]).to eq true
        end
      end
    end

    describe '#merge!' do
      subject(:params) { described_class.send(:new, base) }

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
        let(:key) { rand.to_s.to_sym }
        let(:base) { { key.to_s => initial_value } }

        it 'expect to keep initial values' do
          params.send :merge!, key.to_sym => rand
          expect(params[key]).to eq initial_value
        end
      end
    end

    %i[
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

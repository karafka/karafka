# frozen_string_literal: true

RSpec.describe Karafka::Params::Params do
  describe 'class methods' do
    subject(:params_class) { described_class }

    describe '#build' do
      let(:merged_with_defaults) { double }
      let(:parser) { Karafka::Parsers::Json }

      context 'when we build from a hash' do
        let(:message) { { rand => rand } }

        it 'expect to build based on a message' do
          expect(params_class.build(message, parser)).to eq message.merge('parser' => parser)
        end
      end

      context 'when we build based on Karafka::Connection::Message' do
        let(:content) { rand }
        let(:extra_content) do
          {
            'parser' => parser,
            'parsed' => false,
            'received_at' => Time.now,
            'content' => content
          }
        end
        let(:message) do
          Karafka::Connection::Message.new(rand, content)
        end

        it 'expect to build with additional values and content' do
          Timecop.freeze do
            expect(params_class.build(message, parser)).to eq extra_content.merge('content' => content)
          end
        end
      end
    end
  end

  describe 'instance methods' do
    subject(:params) { described_class.send(:new, {}) }

    describe '#retrieve' do
      context 'when params are already parsed' do
        before do
          params[:parsed] = true
        end

        it 'expect not to parse again and return self' do
          expect(params)
            .not_to receive(:parse)

          expect(params)
            .not_to receive(:merge!)

          expect(params.retrieve).to eq params
        end
      end

      context 'when params were not yet parsed' do
        let(:content) { double }

        before do
          params[:parsed] = false
          params[:content] = content

          expect(params)
            .to receive(:parse)
            .with(content)
            .and_return(parsed_content)
        end

        context 'when parsed content does not contain same keys as already existing' do
          let(:parsed_content) { { double => double } }

          it 'expect to merge with parsed stuff that is under content key and remove this key' do
            expect(params.retrieve[parsed_content.keys[0]]).to eq parsed_content.values[0]
            expect(params.keys).not_to include :content
          end
        end

        context 'when parsed content contains same keys as already existing' do
          let(:parsed_content) { { received_at: rand } }

          it 'expect not to overwrite existing keys' do
            params.retrieve
            expect(params[parsed_content[:received_at]]).not_to eq parsed_content[:received_at]
            expect(params.keys).not_to include :content
          end
        end
      end
    end

    describe '#parse' do
      let(:parser) { double }
      let(:content) { double }

      before do
        params[:parser] = parser
        params[:parsed] = false
      end

      context 'when we are able to successfully parse' do
        let(:parsed_content) { { rand => rand } }

        before do
          expect(parser)
            .to receive(:parse)
            .with(content)
            .and_return(parsed_content)
        end

        it 'expect to mark as parsed and return content in a message key' do
          expect(params.send(:parse, content)).to eq parsed_content
          expect(params[:parsed]).to eq true
        end
      end

      context 'when parsing fails' do
        before do
          expect(parser)
            .to receive(:parse)
            .with(content)
            .and_raise(::Karafka::Errors::ParserError)
        end

        it 'expect to monitor, mark as parsed and return content in a message key' do
          expect(Karafka.monitor)
            .to receive(:notice_error)

          expect(params.send(:parse, content)).to eq(message: content)
          expect(params[:parsed]).to eq true
        end
      end
    end

    describe '#merge!' do
      subject(:params) { described_class.send(:new, base) }

      context 'string based params merge with string key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          params.send :merge!, key => rand
          expect(params[key]).to eq initial_value
        end
      end

      context 'string based params merge with symbol key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          params.send :merge!, key.to_sym => rand
          expect(params[key]).to eq initial_value
        end
      end

      context 'symbol based params merge with symbol key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s.to_sym }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          params.send :merge!, key.to_sym => rand
          expect(params[key]).to eq initial_value
        end
      end

      context 'symbol based params merge with string key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s.to_sym }
        let(:base) { { key.to_s => initial_value } }

        it 'expect to keep initial values' do
          params.send :merge!, key.to_sym => rand
          expect(params[key]).to eq initial_value
        end
      end
    end
  end
end

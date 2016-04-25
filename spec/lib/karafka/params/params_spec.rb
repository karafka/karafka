require 'spec_helper'

RSpec.describe Karafka::Params::Params do
  describe 'class methods' do
    subject { described_class }

    describe '#build' do
      let(:controller) { double }
      let(:defaults) { double }
      let(:merged_with_defaults) { double }

      before do
        expect(subject)
          .to receive(:defaults)
          .with(controller)
          .and_return(defaults)
      end

      context 'when we build from a hash' do
        let(:message) { { rand => rand } }

        it 'expect to build a new based on defaults and merge a message' do
          expect(defaults)
            .to receive(:merge!)
            .with(message)
            .and_return(merged_with_defaults)

          expect(subject.build(message, controller)).to eq merged_with_defaults
        end
      end

      context 'when we build based on Karafka::Connection::Message' do
        let(:content) { rand }

        let(:message) do
          double(
            content: content
          )
        end

        it 'expect to build defaults and merge with additional values and content' do
          Timecop.freeze do
            expect(defaults)
              .to receive(:merge!)
              .with(
                parsed: false,
                received_at: Time.now,
                content: content
              )
              .and_return(merged_with_defaults)

            expect(subject.build(message, controller)).to eq merged_with_defaults
          end
        end
      end
    end

    describe '#defaults' do
      let(:worker) { double }
      let(:parser) { double }
      let(:topic) { double }

      let(:controller) do
        double(
          worker: worker,
          parser: parser,
          topic: topic
        )
      end

      it 'expect to return default params' do
        params = subject.send(:defaults, controller)

        expect(params).to be_a subject
        expect(params[:controller]).to eq controller.class
        expect(params[:worker]).to eq worker
        expect(params[:parser]).to eq parser
        expect(params[:topic]).to eq topic
      end
    end
  end

  describe 'instance methods' do
    subject { described_class.send(:new, {}) }

    describe '#retrieve' do
      context 'when params are already parsed' do
        before do
          subject[:parsed] = true
        end

        it 'expect not to parse again and return self' do
          expect(subject)
            .not_to receive(:parse)

          expect(subject)
            .not_to receive(:merge!)

          expect(subject.retrieve).to eq subject
        end
      end

      context 'when params were not yet parsed' do
        let(:content) { double }

        before do
          subject[:parsed] = false
          subject[:content] = content

          expect(subject)
            .to receive(:parse)
            .with(content)
            .and_return(parsed_content)
        end

        context 'when parsed content does not contain same keys as already existing' do
          let(:parsed_content) { { double => double } }

          it 'expect to merge with parsed stuff that is under content key and remove this key' do
            expect(subject.retrieve[parsed_content.keys[0]]).to eq parsed_content.values[0]
            expect(subject.keys).not_to include :content
          end
        end

        context 'when parsed content contains same keys as already existing' do
          let(:parsed_content) { { received_at: rand } }

          it 'expect not to overwrite existing keys' do
            subject.retrieve
            expect(subject[parsed_content[:received_at]]).not_to eq parsed_content[:received_at]
            expect(subject.keys).not_to include :content
          end
        end
      end
    end

    describe '#parse' do
      let(:parser) { double }
      let(:content) { double }

      before do
        subject[:parser] = parser
        subject[:parsed] = false
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
          expect(subject.send(:parse, content)).to eq parsed_content
          expect(subject[:parsed]).to eq true
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

          expect(subject.send(:parse, content)).to eq(message: content)
          expect(subject[:parsed]).to eq true
        end
      end
    end

    describe '#merge!' do
      subject { described_class.send(:new, base) }

      context 'string based params merge with string key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          subject.send :merge!, key => rand
          expect(subject[key]).to eq initial_value
        end
      end

      context 'string based params merge with symbol key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          subject.send :merge!, key.to_sym => rand
          expect(subject[key]).to eq initial_value
        end
      end

      context 'symbol based params merge with symbol key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s.to_sym }
        let(:base) { { key => initial_value } }

        it 'expect to keep initial values' do
          subject.send :merge!, key.to_sym => rand
          expect(subject[key]).to eq initial_value
        end
      end

      context 'symbol based params merge with string key' do
        let(:initial_value) { rand }
        let(:key) { rand.to_s.to_sym }
        let(:base) { { key.to_s => initial_value } }

        it 'expect to keep initial values' do
          subject.send :merge!, key.to_sym => rand
          expect(subject[key]).to eq initial_value
        end
      end
    end
  end
end

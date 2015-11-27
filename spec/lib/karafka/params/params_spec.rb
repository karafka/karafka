require 'spec_helper'

RSpec.describe Karafka::Params do
=begin
  let(:topic) { rand.to_s }
  let(:content) { rand.to_s }
  let(:message) { Karafka::Connection::Message.new(topic, content) }
  let(:controller) { controller_class.new }
  let(:controller_class) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  subject { described_class.new(message, controller) }

  describe '.initialize' do
    it 'should remember controller class' do
      expect(subject.instance_variable_get(:@controller_class)).to eq controller.class
    end

    it 'should remember raw message' do
      expect(subject.instance_variable_get(:@message)).to eq message
    end

    it 'should not be parsed' do
      expect(subject.instance_variable_get(:@parsed)).to eq false
    end

    it 'should mark Time.now as received_at time' do
      Timecop.freeze do
        expect(subject.instance_variable_get(:@received_at)).to eq Time.now
      end
    end
  end

  describe '#parse!' do
    let(:content) { { rand => rand } }
    let(:metadata) { { rand => rand } }

    it 'should merge content, metadata and mark self as parsed' do
      expect(subject)
        .to receive(:content)
        .and_return(content)

      expect(subject)
        .to receive(:metadata)
        .and_return(metadata)

      expect(subject)
        .to receive(:merge!)
        .with(content)

      expect(subject)
        .to receive(:merge!)
        .with(metadata)

      expect(subject.instance_variable_get(:@parsed)).to eq false

      subject.send(:parse!)

      expect(subject.instance_variable_get(:@parsed)).to eq true
    end
  end

  describe '#fetch' do
    before do
      subject.instance_variable_set(:@parsed, parsed)
    end

    context 'if data has already been parsed' do
      let(:parsed) { true }

      it 'should just return self and not parse again' do
        expect(subject)
          .not_to receive(:parse!)

        expect(subject.fetch).to eq subject
      end
    end

    context 'if data has not been parsed yet' do
      let(:parsed) { false }

      it 'should parse and then return self' do
        expect(subject)
          .to receive(:parse!)

        expect(subject.fetch).to eq subject
      end
    end
  end

  describe '#content' do
    context 'when message is already a hash' do
      let(:message) { { rand => rand } }

      it 'should not try to parse it and just return it' do
        expect(subject.send(:content)).to eq message
      end
    end

    context 'when message is not a hash' do
      let(:parsed_message) { double }

      it 'should use controllers parser to parse message content' do
        expect(controller_class.parser)
          .to receive(:parse)
          .with(message.content)
          .and_return(parsed_message)

        expect(subject.send(:content)).to eq parsed_message
      end
    end

    context 'when during parsing something went wrong' do
      before do
        expect(controller_class.parser)
          .to receive(:parse)
          .and_raise(controller_class.parser::ParserError)
      end

      it 'should assign a raw data inside message key' do
        expect(subject.send(:content)).to eq(message: message.content)
      end
    end
  end

  describe '#metadata' do
    it 'expect metadata to be build using controller and internal details' do
      Timecop.freeze do
        expected = {
          controller: controller_class,
          worker: controller_class.worker,
          parser: controller_class.parser,
          topic: controller_class.topic,
          received_at: Time.now
        }

        expect(subject.send(:metadata)).to eq expected
      end
    end
  end
=end
  pending
end

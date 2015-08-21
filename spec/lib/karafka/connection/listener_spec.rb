require 'spec_helper'

RSpec.describe Karafka::Connection::Listener do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform; end
    end
  end

  subject { described_class.new(controller) }

  describe '#fetch' do
    described_class::IGNORED_ERRORS.each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        it 'should close the consumer and not raise error' do
          expect(subject)
            .to receive(:consumer)
            .and_return(proxy)
            .at_least(:once)

          expect(proxy)
            .to receive(:fetch)
            .and_raise(error.new)

          expect(proxy)
            .to receive(:close)

          expect { subject.send(:fetch) }.not_to raise_error
        end
      end
    end

    context 'when unexpected error occurs' do
      let(:error) { StandardError }

      it 'should close the consumer and raise error' do
        expect(subject)
          .to receive(:consumer)
          .and_return(proxy)
          .at_least(:once)

        expect(proxy)
          .to receive(:fetch)
          .and_raise(error)

        expect(proxy)
          .to receive(:close)

        expect { subject.send(:fetch) }.to raise_error(error)
      end
    end

    context 'when no errors occur' do
      let(:consumer) { double }
      let(:_partition) { double }
      let(:messages_bulk) { [incoming_message] }
      let(:incoming_message) { double }

      it 'should yield for each incoming message' do
        expect(subject)
          .to receive(:consumer)
          .and_return(consumer)
          .at_least(:once)

        expect(consumer)
          .to receive(:fetch)
          .and_yield(_partition, messages_bulk)

        expect(subject)
          .to receive(:message)
          .with(incoming_message)

        expect(consumer)
          .to receive(:close)

        subject.send(:fetch) do
        end
      end
    end
  end

  describe '#message' do
    let(:message) { double }
    let(:content) { rand }
    let(:incoming_message) { double(value: content) }

    it 'should create an message instance' do
      expect(Karafka::Connection::Message)
        .to receive(:new)
        .with(controller.topic, content)
        .and_return(message)

      expect(subject.send(:message, incoming_message)).to eq message
    end
  end

  describe '#consumer' do
    context 'when consumer is already created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', consumer)
      end

      it 'should just return it' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .never
        expect(subject.send(:consumer)).to eq consumer
      end
    end

    context 'when consumer is not yet created' do
      let(:consumer) { double }

      before do
        subject.instance_variable_set(:'@consumer', nil)
      end

      it 'should create an instance and return' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .with(
            controller.group.to_s,
            Karafka::App.config.kafka_hosts,
            Karafka::App.config.zookeeper_hosts,
            controller.topic.to_s
          )
          .and_return(consumer)

        expect(subject.send(:consumer)).to eq consumer
      end
    end
  end
end

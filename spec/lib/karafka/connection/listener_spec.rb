require 'spec_helper'

RSpec.describe Karafka::Connection::Listener do
  let(:controller) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  subject { described_class.new(controller) }

  describe '#fetch' do
    let(:action) { double }
    [
      ZK::Exceptions::OperationTimeOut,
      Poseidon::Connection::ConnectionFailedError,
      Exception
    ].each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        before do
          # Lets silence exceptions printing
          expect(Karafka.logger)
            .to receive(:error)
            .exactly(2).times
        end

        it 'should log the error wthout closing the consumer' do
          expect(subject)
            .to receive(:queue_consumer)
            .and_raise(error.new)

          expect(subject)
            .not_to receive(:queue_consumer)

          expect { subject.send(:fetch, action) }.not_to raise_error
        end
      end
    end

    context "when one of #{Poseidon::Errors::ProtocolError} happen" do
      let(:error) { Poseidon::Errors::ProtocolError }
      let(:queue_consumer) { double }

      before do
        expect(subject)
          .to receive(:queue_consumer)
          .and_return(queue_consumer)

        expect(queue_consumer)
          .to receive(:fetch)
          .and_raise(error.new)

        subject.instance_variable_set(:@queue_consumer, queue_consumer)
      end

      it 'should close the consumer and not raise error' do
        expect(subject.instance_variable_get(:@queue_consumer)).to eq queue_consumer

        expect(queue_consumer)
          .to receive(:close)

        expect { subject.send(:fetch, action) }.not_to raise_error
        expect(subject.instance_variable_get(:@queue_consumer)).to eq nil
      end
    end

    context 'when no errors occur' do
      let(:queue_consumer) { double }
      let(:_partition) { double }
      let(:messages_bulk) { [incoming_message] }
      let(:incoming_message) { double }

      it 'should yield for each incoming message' do
        expect(subject)
          .to receive(:queue_consumer)
          .and_return(queue_consumer)
          .at_least(:once)

        expect(queue_consumer)
          .to receive(:fetch)
          .and_yield(_partition, messages_bulk)
        expect(action)
          .to receive(:call)
          .with(subject.controller, incoming_message)

        subject.send(:fetch, action)
      end
    end
  end

  describe '#queue_consumer' do
    context 'when queue_consumer is already created' do
      let(:queue_consumer) { double }

      before do
        subject.instance_variable_set(:'@queue_consumer', queue_consumer)
      end

      it 'should just return it' do
        expect(Poseidon::ConsumerGroup)
          .to receive(:new)
          .never
        expect(subject.send(:queue_consumer)).to eq queue_consumer
      end
    end

    context 'when queue_consumer is not yet created' do
      let(:queue_consumer) { double }

      before do
        subject.instance_variable_set(:'@queue_consumer', nil)
      end

      it 'should create an instance and return' do
        expect(Karafka::Connection::QueueConsumer)
          .to receive(:new)
          .with(controller)
          .and_return(queue_consumer)

        expect(subject.send(:queue_consumer)).to eq queue_consumer
      end
    end
  end
end

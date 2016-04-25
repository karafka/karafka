require 'spec_helper'

RSpec.describe Karafka::Connection::Listener do
  let(:route) do
    Karafka::Routing::Route.new.tap do |route|
      route.topic = rand.to_s
      route.group = rand.to_s
    end
  end

  subject { described_class.new(route) }

  describe '#fetch' do
    let(:queue_consumer) { double }
    let(:_partition) { double }
    let(:incoming_message) { double }
    let(:messages_bulk) { [incoming_message] }

    let(:action) { double }
    [
      StandardError,
      Exception
    ].each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        before do
          # Lets silence exceptions printing
          expect(Karafka.monitor)
            .to receive(:notice_error)
            .with(described_class, error)
        end

        it 'notices the error wthout closing the consumer' do
          expect(subject)
            .to receive(:queue_consumer)
            .and_raise(error.new)

          expect(subject)
            .not_to receive(:queue_consumer)

          expect { subject.send(:fetch, action) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      before do
        expect(Karafka::App)
          .to receive(:running?)
          .and_return(true)
      end

      it 'expect to yield for each incoming message and return last one' do
        expect(subject)
          .to receive(:queue_consumer)
          .and_return(queue_consumer)
          .at_least(:once)

        expect(queue_consumer)
          .to receive(:fetch)
          .and_yield(_partition, messages_bulk)

        expect(action)
          .to receive(:call)
          .with(incoming_message)

        expect(subject.send(:fetch, action)).to eq incoming_message
      end
    end

    context 'when app is no longer running' do
      let(:messages_bulk) { [incoming_message, double] }

      before do
        expect(Karafka::App)
          .to receive(:running?)
          .and_return(false)
      end

      it 'expect to process first message and then return it' do
        expect(subject)
          .to receive(:queue_consumer)
          .and_return(queue_consumer)
          .at_least(:once)

        expect(queue_consumer)
          .to receive(:fetch)
          .and_yield(_partition, messages_bulk)

        expect(action)
          .to receive(:call)
          .with(incoming_message)

        expect(subject.send(:fetch, action)).to eq incoming_message
      end
    end
  end

  describe '#queue_consumer' do
    context 'when queue_consumer is already created' do
      let(:queue_consumer) { double }

      before do
        subject.instance_variable_set(:'@queue_consumer', queue_consumer)
      end

      it 'just returns it' do
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

      it 'creates an instance and return' do
        expect(Karafka::Connection::QueueConsumer)
          .to receive(:new)
          .with(route)
          .and_return(queue_consumer)

        expect(subject.send(:queue_consumer)).to eq queue_consumer
      end
    end
  end
end

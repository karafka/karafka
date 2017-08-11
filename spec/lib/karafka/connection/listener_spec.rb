# frozen_string_literal: true

RSpec.describe Karafka::Connection::Listener do
  subject(:listener) { described_class.new(consumer_group).wrapped_object }

  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, rand.to_s) do
        controller Class.new
        inline_processing true
      end
    end
  end

  describe '#fetch_loop' do
    let(:messages_consumer) { double }
    let(:incoming_message) { double }
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

        it 'notices the error and stop the consumer' do
          expect(listener)
            .to receive(:messages_consumer)
            .and_raise(error.new)

          expect { listener.fetch_loop(-> {}) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      it 'expect to yield for each incoming message' do
        expect(listener).to receive(:messages_consumer).and_return(messages_consumer)
        expect(messages_consumer).to receive(:fetch_loop).and_yield(incoming_message)
        expect(action).to receive(:call).with(consumer_group.id, incoming_message)

        listener.send(:fetch_loop, action)
      end
    end
  end

  describe '#messages_consumer' do
    context 'when messages_consumer is already created' do
      let(:messages_consumer) { double }

      before do
        listener.instance_variable_set(:'@messages_consumer', messages_consumer)
      end

      it 'just returns it' do
        expect(Karafka::Connection::MessagesConsumer)
          .to receive(:new)
          .never
        expect(listener.send(:messages_consumer)).to eq messages_consumer
      end
    end

    context 'when messages_consumer is not yet created' do
      let(:messages_consumer) { double }

      before do
        listener.instance_variable_set(:'@messages_consumer', nil)
      end

      it 'creates an instance and return' do
        expect(Karafka::Connection::MessagesConsumer)
          .to receive(:new)
          .with(consumer_group)
          .and_return(messages_consumer)

        expect(listener.send(:messages_consumer)).to eq messages_consumer
      end
    end
  end
end

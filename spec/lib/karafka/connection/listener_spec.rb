# frozen_string_literal: true

RSpec.describe Karafka::Connection::Listener do
  subject(:listener) { described_class.new(consumer_group) }

  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, rand.to_s) do
        controller Class.new(Karafka::BaseController)
        backend :inline
      end
    end
  end

  describe '#fetch_loop' do
    let(:consumer) { double }
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
            .to receive(:consumer)
            .and_raise(error.new)

          expect { listener.fetch_loop(-> {}) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      it 'expect to yield for each incoming message' do
        expect(listener).to receive(:consumer).and_return(consumer)
        expect(consumer).to receive(:fetch_loop).and_yield(incoming_message)
        expect(action).to receive(:call).with(consumer_group.id, incoming_message)

        listener.send(:fetch_loop, action)
      end
    end
  end

  describe '#consumer' do
    context 'when consumer is already created' do
      let(:consumer) { double }

      before do
        listener.instance_variable_set(:'@consumer', consumer)
      end

      it 'just returns it' do
        expect(Karafka::Connection::Consumer)
          .to receive(:new)
          .never
        expect(listener.send(:consumer)).to eq consumer
      end
    end

    context 'when consumer is not yet created' do
      let(:consumer) { double }

      before do
        listener.instance_variable_set(:'@consumer', nil)
      end

      it 'creates an instance and return' do
        expect(Karafka::Connection::Consumer)
          .to receive(:new)
          .with(consumer_group)
          .and_return(consumer)

        expect(listener.send(:consumer)).to eq consumer
      end
    end
  end
end

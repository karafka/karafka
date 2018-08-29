# frozen_string_literal: true

RSpec.describe Karafka::Connection::Listener do
  subject(:listener) { described_class.new(consumer_group) }

  let(:consumer_group) do
    Karafka::Routing::ConsumerGroup.new(rand.to_s).tap do |cg|
      cg.public_send(:topic=, rand.to_s) do
        consumer Class.new(Karafka::BaseConsumer)
        backend :inline
      end
    end
  end

  describe '#call' do
    let(:client) { listener.send(:client) }

    it 'expects to run callbacks and start the main fetch loop' do
      expect(Karafka::Callbacks).to receive(:before_fetch_loop).with(consumer_group, client)
      expect(client).to receive(:fetch_loop)
      listener.call
    end
  end

  describe '#fetch_loop' do
    let(:client) { double }
    let(:incoming_message) { double }

    [
      StandardError,
      Exception
    ].each do |error|
      let(:proxy) { double }

      context "when #{error} happens" do
        before do
          # Lets silence exceptions printing
          allow(Karafka.monitor)
            .to receive(:instrument)
            .with(
              'connection.listener.fetch_loop.error',
              caller: listener,
              error: error
            )
        end

        it 'notices the error and stop the client' do
          expect(listener)
            .to receive(:client)
            .and_raise(error.new)

          expect { listener.send(:fetch_loop) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      it 'expect to yield for each incoming message' do
        expect(listener).to receive(:client).and_return(client)
        expect(client).to receive(:fetch_loop).and_yield(incoming_message)

        listener.send(:fetch_loop)
      end
    end
  end

  describe '#client' do
    context 'when client is already created' do
      let(:client) { double }

      before do
        listener.instance_variable_set(:'@client', client)
      end

      it 'just returns it' do
        expect(Karafka::Connection::Client)
          .not_to receive(:new)
        expect(listener.send(:client)).to eq client
      end
    end

    context 'when client is not yet created' do
      let(:client) { double }

      before do
        listener.instance_variable_set(:'@client', nil)
      end

      it 'creates an instance and return' do
        expect(Karafka::Connection::Client)
          .to receive(:new)
          .with(consumer_group)
          .and_return(client)

        expect(listener.send(:client)).to eq client
      end
    end
  end
end

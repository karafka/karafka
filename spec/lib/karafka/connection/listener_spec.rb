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
    let(:client) { double }
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

        it 'notices the error and stop the client' do
          expect(listener)
            .to receive(:client)
            .and_raise(error.new)

          expect { listener.fetch_loop(-> {}) }.not_to raise_error
        end
      end
    end

    context 'when no errors occur' do
      it 'expect to yield for each incoming message' do
        expect(listener).to receive(:client).and_return(client)
        expect(client).to receive(:fetch_loop).and_yield(incoming_message)
        expect(action).to receive(:call).with(consumer_group.id, incoming_message)

        listener.send(:fetch_loop, action)
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
          .to receive(:new)
          .never
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

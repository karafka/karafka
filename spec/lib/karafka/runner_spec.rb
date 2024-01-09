# frozen_string_literal: true

RSpec.describe_current do
  subject(:runner) { described_class.new }

  describe '#call' do
    # We need to set it to 0 as otherwise the listener would always wait for workers threads that
    # would never stop without shutting down whole framework
    before { Karafka::App.config.concurrency = 0 }

    after { Karafka::App.config.concurrency = 5 }

    let(:subscription_group) { create(:routing_subscription_group) }

    context 'when everything is ok' do
      let(:listeners) { [listener] }
      let(:async_scope) { listener }
      let(:listener) do
        instance_double(
          Karafka::Connection::Listener,
          start!: nil,
          stopped?: false,
          quiet!: true,
          quiet?: true,
          stop!: true,
          subscription_group: subscription_group
        )
      end

      before do
        allow(Karafka::App.config.internal.connection.conductor)
          .to receive(:wait)
        allow(Karafka::App.config.internal.connection.manager)
          .to receive(:done?)
          .and_return(true)

        allow(Karafka::Connection::ListenersBatch)
          .to receive(:new)
          .and_return(listeners)

        allow(Karafka::App)
          .to receive(:done?)
          .and_return(true)
      end

      it 'starts asynchronously consumption for each listener' do
        runner.call
      end
    end

    context 'when something goes wrong internaly' do
      let(:error) { StandardError }

      let(:instrument_args) do
        ['error.occurred', { caller: runner, error: error, type: 'runner.call.error' }]
      end

      before do
        allow(Karafka::Processing::JobsQueue).to receive(:new).and_raise(error)
        allow(Karafka::App).to receive(:stop!)
        allow(Karafka.monitor).to receive(:instrument)
      end

      it 'stops the app and reraise' do
        expect { runner.call }.to raise_error(error)
        expect(Karafka.monitor).to have_received(:instrument).with(*instrument_args)
        expect(Karafka::App).to have_received(:stop!).with(no_args)
      end
    end
  end
end

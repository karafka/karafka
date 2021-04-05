# frozen_string_literal: true

RSpec.describe Karafka::Runner do
  subject(:runner) { described_class.new }

  describe '#call' do
    context 'when everything is ok' do
      let(:listeners) { [listener] }
      let(:async_scope) { listener }
      let(:listener) { instance_double(Karafka::Connection::Listener, call: nil) }

      before do
        allow(runner)
          .to receive(:listeners)
          .and_return(listeners)
      end

      it 'starts asynchronously consumption for each listener' do
        runner.call
      end
    end

    context 'when something goes wrong internaly' do
      let(:error) { StandardError }
      let(:instrument_args) { ['runner.call.error', { caller: runner, error: error }] }

      before do
        allow(runner)
          .to receive(:listeners)
          .and_raise(error)
      end

      it 'stops the app and reraise' do
        expect(Karafka::App).to receive(:stop!)
        expect(Karafka.monitor).to receive(:instrument).with(*instrument_args)
        expect { runner.call }.to raise_error(error)
      end
    end
  end

  describe '#listeners' do
    let(:jobs_queue) { double }
    let(:subscription_group) { double }
    let(:subscription_groups) { [subscription_group] }

    before do
      expect(Karafka::App)
        .to receive(:subscription_groups)
        .and_return(subscription_groups)

      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(subscription_group, jobs_queue)
    end

    it { expect(runner.send(:listeners, jobs_queue)).to be_a(Array) }
  end
end

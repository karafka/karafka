# frozen_string_literal: true

RSpec.describe_current do
  subject(:monitor) { described_class.new }

  describe '#instrument' do
    let(:result) { rand }
    let(:event_name) { 'connection.listener.fetch_loop.error' }
    let(:consumer) { instance_double(Karafka::BaseConsumer, topic: rand.to_s) }
    let(:instrumentation) do
      monitor.instrument(
        event_name,
        caller: self,
        consumer: consumer,
        error: StandardError
      ) { result }
    end

    it 'expect to return blocks execution value' do
      expect(instrumentation).to eq result
    end
  end

  describe '#subscribe' do
    context 'when we have a block based listener' do
      let(:subscription) { Karafka.monitor.subscribe(event_name) {} }
      let(:exception) { Karafka::Core::Monitoring::Notifications::EventNotRegistered }

      context 'when we try to subscribe to an unsupported event' do
        let(:event_name) { 'unsupported' }

        it { expect { subscription }.to raise_error exception }
      end

      context 'when we try to subscribe to a supported event' do
        let(:event_name) { 'error.occurred' }

        it { expect { subscription }.not_to raise_error }
      end
    end

    context 'when we have an object listener' do
      let(:subscription) { Karafka.monitor.subscribe(listener.new) }
      let(:listener) do
        Class.new do
          def on_error_occurred(_event)
            true
          end
        end
      end

      it { expect { subscription }.not_to raise_error }
    end
  end
end

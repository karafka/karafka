# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Monitor do
  subject(:monitor) { described_class.instance }

  describe '#instrument' do
    let(:result) { rand }
    let(:instrumentation) { monitor.instrument(event_name, call: self) { result } }
    let(:event_name) { monitor.available_events.sample }

    it 'expect to return blocks execution value' do
      expect(instrumentation).to eq result
    end
  end

  describe '#subscribe' do
    context 'when we have a block based listener' do
      let(:subscription) { Karafka.monitor.subscribe(event_name) {} }

      context 'when we try to subscribe to an unsupported event' do
        let(:event_name) { 'unsupported' }

        it { expect { subscription }.to raise_error Karafka::Errors::UnregisteredMonitorEvent }
      end

      context 'when we try to subscribe to a supported event' do
        let(:event_name) { monitor.available_events.sample }

        it { expect { subscription }.not_to raise_error }
      end
    end

    context 'when we have an object listener' do
      let(:subscription) { Karafka.monitor.subscribe(listener) }
      let(:listener) { Class.new }

      it { expect { subscription }.not_to raise_error }
    end
  end

  describe '#available_events' do
    it 'expect to include registered events' do
      expect(monitor.available_events.size).to eq 9
    end

    it { expect(monitor.available_events).to include 'connection.listener.fetch_loop_error' }
  end
end

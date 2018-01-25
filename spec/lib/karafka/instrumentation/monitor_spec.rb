# frozen_string_literal: true

RSpec.describe Karafka::Instrumentation::Monitor do
  subject(:monitor) { described_class.instance }

  describe '#instrument' do
    let(:result) { rand }
    let(:instrumentation) { monitor.instrument(event_name, self) { result } }
    let(:event_name) { monitor.available_events.sample }

    it 'expect to return blocks execution value' do
      expect(instrumentation).to eq result
    end
  end

  describe '#subscribe' do
    context 'for a block based listener' do
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

    context 'for an object listener' do
      pending
    end
  end

  describe '#available_events' do
    it 'expect to include registered events' do
      expect(monitor.available_events.size).to eq 8
    end

    it { expect(monitor.available_events).to include 'connection.listener.fetch_loop_error' }
  end
end

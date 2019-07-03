# frozen_string_literal: true

RSpec.describe Karafka::Fetcher do
  subject(:fetcher) { described_class.new }

  describe '#fetch_loop' do
    context 'when everything is ok' do
      let(:listeners) { [listener] }
      let(:async_scope) { listener }
      let(:listener) { instance_double(Karafka::Connection::Listener, call: nil) }

      before do
        allow(fetcher)
          .to receive(:listeners)
          .and_return(listeners)
      end

      it 'starts asynchronously consumption for each listener' do
        fetcher.call
      end
    end

    context 'when something goes wrong internaly' do
      let(:error) { StandardError }
      let(:instrument_args) { ['fetcher.call.error', caller: fetcher, error: error] }

      before do
        allow(fetcher)
          .to receive(:listeners)
          .and_raise(error)
      end

      it 'stops the app and reraise' do
        expect(Karafka::App).to receive(:stop!)
        expect(Karafka.monitor).to receive(:instrument).with(*instrument_args)
        expect { fetcher.call }.to raise_error(error)
      end
    end
  end

  describe '#listeners' do
    let(:consumer_group) { double }
    let(:consumer_groups) { OpenStruct.new(active: [consumer_group]) }

    before do
      expect(Karafka::App)
        .to receive(:consumer_groups)
        .and_return(consumer_groups)

      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(consumer_group)
    end

    it { expect(fetcher.send(:listeners)).to be_a(Array) }
  end
end

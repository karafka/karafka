# frozen_string_literal: true

RSpec.describe Karafka::Fetcher do
  subject(:fetcher) { described_class.new }

  describe '#fetch_loop' do
    context 'when everything is ok' do
      let(:listeners) { [listener] }
      let(:delegator) { -> {} }
      let(:async_scope) { listener }
      let(:listener) { instance_double(Karafka::Connection::Listener, fetch_loop: nil) }

      before do
        allow(fetcher)
          .to receive(:listeners)
          .and_return(listeners)

        expect(fetcher)
          .to receive(:delegator)
          .and_return(delegator)
      end

      it 'starts asynchronously consumption for each listener' do
        fetcher.fetch_loop
      end
    end

    context 'when something goes wrong internaly' do
      let(:error) { StandardError }

      before do
        expect(fetcher)
          .to receive(:listeners)
          .and_raise(error)
      end

      it 'stops the app and reraise' do
        expect(Karafka::App).to receive(:stop!)
        expect(Karafka.monitor).to receive(:notice_error).with(described_class, error)
        expect { fetcher.fetch_loop }.to raise_error(error)
      end
    end
  end

  describe '#delegator' do
    subject(:fetcher) { described_class.new.send(:delegator) }

    it 'is a proc' do
      expect(fetcher).to be_a Proc
    end

    context 'when we invoke a delegator block' do
      let(:message) { double }
      let(:delegator) { Karafka::Connection::Delegator }
      let(:consumer_group_id) { rand.to_s }

      it 'process the message' do
        expect(delegator)
          .to receive(:call)
          .with(consumer_group_id, message)

        fetcher.call(consumer_group_id, message)
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

    it { expect(fetcher.send(:listeners)).to be_a Array }
  end
end

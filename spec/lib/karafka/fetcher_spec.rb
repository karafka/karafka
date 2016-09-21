RSpec.describe Karafka::Fetcher do
  subject(:fetcher) { described_class.new }

  describe '#fetch_loop' do
    context 'when everything is ok' do
      let(:future) { instance_double(Celluloid::Future, value: rand) }
      let(:listeners) { [listener] }
      let(:consumer) { -> {} }
      let(:async_scope) { listener }
      let(:listener) do
        instance_double(
          Karafka::Connection::Listener,
          fetch_loop: future,
          terminate: true
        )
      end

      before do
        allow(fetcher)
          .to receive(:listeners)
          .and_return(listeners)

        expect(fetcher)
          .to receive(:consumer)
          .and_return(consumer)
      end

      it 'starts asynchronously consumption for each listener' do
        expect(listener)
          .to receive(:future)
          .and_return(async_scope)

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
        expect(Karafka::App)
          .to receive(:stop!)

        expect(Karafka.monitor)
          .to receive(:notice_error)
          .with(described_class, error)

        expect { fetcher.fetch_loop }.to raise_error(error)
      end
    end
  end

  describe '#consumer' do
    subject(:fetcher) { described_class.new.send(:consumer) }

    it 'is a proc' do
      expect(fetcher).to be_a Proc
    end

    context 'when we invoke a consumer block' do
      let(:message) { double }
      let(:consumer) { Karafka::Connection::Consumer.new }

      before do
        expect(Karafka::Connection::Consumer)
          .to receive(:new)
          .and_return(consumer)
      end

      it 'consumes the message' do
        expect(consumer)
          .to receive(:consume)
          .with(message)

        fetcher.call(message)
      end
    end
  end

  describe '#listeners' do
    let(:route) { double }
    let(:routes) { [route] }

    before do
      expect(Karafka::App)
        .to receive(:routes)
        .and_return(routes)

      expect(Karafka::Connection::Listener)
        .to receive(:new)
        .with(route)
    end

    it { expect(fetcher.send(:listeners)).to be_a Array }
  end
end

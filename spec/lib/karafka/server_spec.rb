# frozen_string_literal: true

RSpec.describe Karafka::Server do
  subject(:server_class) { described_class }

  describe '#run' do
    let(:runner) { Karafka::Fetcher.new }

    after { server_class.run }

    context 'when we want to run in supervision' do
      before do
        expect(Karafka::App).to receive(:run!)
        expect(Karafka::Fetcher).to receive(:new).and_return(runner)
        expect(runner).to receive(:fetch_loop)
        expect(Karafka::Process.instance).to receive(:on_sigint)
        expect(Karafka::Process.instance).to receive(:on_sigquit)
        expect(Karafka::Process.instance).to receive(:on_sigterm)
      end

      it 'runs in supervision, start consuming' do
        expect(Karafka::Process.instance).to receive(:supervise).and_yield
      end
    end

    context 'when sigint is received' do
      before do
        allow(Karafka::Process.instance).to receive(:supervise)
        allow(Karafka::Process.instance).to receive(:on_sigquit)
        allow(Karafka::Process.instance).to receive(:on_sigterm)
      end

      it 'defines a proper action for sigint' do
        expect(Karafka::Server).to receive(:stop_supervised)
        expect(Karafka::Process.instance).to receive(:on_sigint).and_yield
      end
    end

    context 'when sigquit is received' do
      before do
        allow(Karafka::Process.instance).to receive(:supervise)
        allow(Karafka::Process.instance).to receive(:on_sigint)
        allow(Karafka::Process.instance).to receive(:on_sigterm)
      end

      it 'defines a proper action for sigquit' do
        expect(Karafka::Server).to receive(:stop_supervised)
        expect(Karafka::Process.instance).to receive(:on_sigquit).and_yield
      end
    end

    context 'when sigterm is received' do
      before do
        allow(Karafka::Process.instance).to receive(:supervise)
        allow(Karafka::Process.instance).to receive(:on_sigint)
        allow(Karafka::Process.instance).to receive(:on_sigquit)
      end

      it 'defines a proper action for sigterm' do
        expect(Karafka::Server).to receive(:stop_supervised)
        expect(Karafka::Process.instance).to receive(:on_sigterm).and_yield
      end
    end
  end

  describe '#stop_supervised' do
    pending
  end
end

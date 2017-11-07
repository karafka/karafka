# frozen_string_literal: true

RSpec.describe Karafka::Server do
  subject(:server_class) { described_class }

  describe '#run' do
    let(:runner) { Karafka::Fetcher.new }

    after { server_class.run }

    context 'supervision' do
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

    context 'sigint' do
      before do
        expect(Karafka::Process.instance).to receive(:supervise)
        expect(Karafka::Process.instance).to receive(:on_sigquit)
        expect(Karafka::Process.instance).to receive(:on_sigterm)
        expect(Karafka::App).to receive(:stop!)
      end

      it 'defines a proper action for sigint' do
        expect(Karafka::Process.instance).to receive(:on_sigint).and_yield
      end
    end

    context 'sigquit' do
      before do
        expect(Karafka::Process.instance).to receive(:supervise)
        expect(Karafka::Process.instance).to receive(:on_sigint)
        expect(Karafka::Process.instance).to receive(:on_sigterm)
        expect(Karafka::App).to receive(:stop!)
      end

      it 'defines a proper action for sigquit' do
        expect(Karafka::Process.instance).to receive(:on_sigquit).and_yield
      end
    end

    context 'sigterm' do
      before do
        expect(Karafka::Process.instance).to receive(:supervise)
        expect(Karafka::Process.instance).to receive(:on_sigint)
        expect(Karafka::Process.instance).to receive(:on_sigquit)
        expect(Karafka::App).to receive(:stop!)
      end

      it 'defines a proper action for sigterm' do
        expect(Karafka::Process.instance).to receive(:on_sigterm).and_yield
      end
    end
  end
end

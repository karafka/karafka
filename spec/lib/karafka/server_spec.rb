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
        expect(described_class).to receive(:stop_supervised)
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
        expect(described_class).to receive(:stop_supervised)
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
        expect(described_class).to receive(:stop_supervised)
        expect(Karafka::Process.instance).to receive(:on_sigterm).and_yield
      end
    end
  end

  describe '#stop_supervised' do
    before { Karafka::App.config.shutdown_timeout = timeout }

    after do
      server_class.send(:stop_supervised)
      described_class.consumer_threads.clear
      # After shutdown we need to reinitialize the app for other specs
      Karafka::App.initialize!
    end

    context 'when there is no shutdown timeout' do
      let(:timeout) { nil }

      it 'expect stop and not exit' do
        expect(Karafka::App).to receive(:stop!)
        expect(Kernel).not_to receive(:exit)
      end
    end

    context 'when shutdown time is 0' do
      let(:timeout) { 0 }

      it 'expect stop and exit without sleep' do
        expect(Karafka::App).to receive(:stop!)
        expect(described_class).not_to receive(:sleep)
        expect(Kernel).to receive(:exit).with(2)
      end
    end

    context 'when shutdown time is more then 1' do
      let(:timeout) { rand(5..15) }

      context 'when there are no active threads (all shutdown ok)' do
        it 'expect stop without exit or sleep' do
          expect(Karafka::App).to receive(:stop!)
          expect(described_class).not_to receive(:sleep)
          expect(Kernel).not_to receive(:exit)
        end
      end

      context 'when there are active threads (processing too long)' do
        let(:active_thread) { instance_double(Thread, alive?: true, terminate: true) }

        before { described_class.consumer_threads << active_thread }

        it 'expect stop and exit with sleep' do
          expect(Karafka::App).to receive(:stop!)
          expect(described_class).to receive(:sleep).with(1).exactly(timeout).times
          expect(Kernel).to receive(:exit).with(2)
        end
      end
    end
  end
end

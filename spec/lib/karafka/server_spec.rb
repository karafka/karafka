# frozen_string_literal: true

RSpec.describe Karafka::Server do
  subject(:server_class) { described_class }

  let(:process) { Karafka::App.config.internal.process }

  describe '#run' do
    after { server_class.run }

    before do
      allow(Karafka::App).to receive(:run!)
      allow(Karafka::App.config.internal.fetcher).to receive(:call)
    end

    context 'when we want to run in supervision' do
      it 'runs in supervision, start consuming' do
        expect(process).to receive(:on_sigint)
        expect(process).to receive(:on_sigquit)
        expect(process).to receive(:on_sigterm)
      end
    end

    context 'when sigint is received' do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigquit)
        allow(process).to receive(:on_sigterm)
      end

      it 'defines a proper action for sigint' do
        expect(described_class).to receive(:stop_supervised)
        expect(process).to receive(:on_sigint).and_yield
      end
    end

    context 'when sigquit is received' do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigint)
        allow(process).to receive(:on_sigterm)
      end

      it 'defines a proper action for sigquit' do
        expect(described_class).to receive(:stop_supervised)
        expect(process).to receive(:on_sigquit).and_yield
      end
    end

    context 'when sigterm is received' do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigint)
        allow(process).to receive(:on_sigquit)
      end

      it 'defines a proper action for sigterm' do
        expect(described_class).to receive(:stop_supervised)
        expect(process).to receive(:on_sigterm).and_yield
      end
    end
  end

  describe '#run_supervised' do
    after { server_class.send(:run_supervised) }

    it 'expect to supervise and run' do
      expect(process).to receive(:supervise)
      expect(Karafka::App).to receive(:run!)
      expect(Karafka::App.config.internal.fetcher).to receive(:call)
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

    context 'when shutdown time is more then 1' do
      let(:timeout) { rand(5..15) }

      context 'when there are no active threads (all shutdown ok)' do
        it 'expect stop without exit or sleep' do
          expect(Karafka::App).to receive(:stop!)
          expect(described_class).not_to receive(:sleep)
          expect(Kernel).not_to receive(:exit!)
        end
      end

      context 'when there are active threads (processing too long)' do
        let(:active_thread) { instance_double(Thread, alive?: true, terminate: true) }

        before { described_class.consumer_threads << active_thread }

        it 'expect stop and exit with sleep' do
          expect(Karafka::App).to receive(:stop!)
          expect(described_class).to receive(:sleep).with(0.1).exactly(timeout * 10).times
          expect(Kernel).to receive(:exit!).with(2)
        end
      end
    end
  end
end

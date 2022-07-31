# frozen_string_literal: true

RSpec.describe_current do
  subject(:server_class) { described_class }

  let(:process) { Karafka::App.config.internal.process }
  let(:runner) { Karafka::Runner.new }

  before do
    allow(Karafka::App).to receive(:run!)
    allow(Karafka::App).to receive(:stopped?).and_return(true)
    allow(Karafka::Runner).to receive(:new).and_return(runner)
    allow(runner).to receive(:call)
    described_class.listeners = []
    described_class.workers = []
  end

  describe '#run' do
    after do
      server_class.run
      # Since stopping happens in a separate thread, we need to wait
      sleep(0.5)
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
        expect(described_class).to receive(:stop)
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
        expect(described_class).to receive(:stop)
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
        expect(described_class).to receive(:stop)
        expect(process).to receive(:on_sigterm).and_yield
      end
    end
  end

  describe '#start' do
    before do
      allow(process).to receive(:supervise)
      allow(Karafka::App).to receive(:run!)
      allow(runner).to receive(:call)

      server_class.start
    end

    it 'expect to supervise and run' do
      expect(process).to have_received(:supervise)
      expect(Karafka::App).to have_received(:run!)
      expect(runner).to have_received(:call)
    end
  end

  describe '#stop' do
    before { Karafka::App.config.shutdown_timeout = timeout_ms }

    after do
      server_class.stop
      described_class.listeners.clear
      described_class.workers = []
      # After shutdown we need to reinitialize the app for other specs
      Karafka::App.initialize!
    end

    context 'when shutdown time is more then 1' do
      let(:timeout_s) { 15 }
      let(:timeout_ms) { timeout_s * 1_000 }

      before do
        allow(Karafka::App).to receive(:stop!)
        allow(described_class).to receive(:sleep)
        allow(Kernel).to receive(:exit!)
      end

      context 'when there are no active threads (all shutdown ok)' do
        before do
          server_class.stop
          described_class.listeners.clear
        end

        it 'expect stop without exit or sleep' do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).not_to have_received(:sleep)
          expect(Kernel).not_to have_received(:exit!)
        end
      end

      context 'when there are active consuming threads (consuming does not want to stop)' do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            alive?: true,
            terminate: true,
            join: true,
            shutdown: true
          )
        end

        before do
          described_class.listeners = [active_thread]
          server_class.stop
          described_class.listeners.clear
        end

        it 'expect stop and exit with sleep' do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(timeout_s * 10).times
          expect(Kernel).to have_received(:exit!).with(2)
        end
      end

      context 'when there are active processing workers (processing does not want to stop)' do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            alive?: true,
            terminate: true,
            join: true,
            shutdown: true
          )
        end

        before do
          described_class.workers = [active_thread]
          server_class.stop
          described_class.workers.clear
        end

        it 'expect stop and exit with sleep' do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(timeout_s * 10).times
          expect(Kernel).to have_received(:exit!).with(2)
        end
      end
    end
  end
end

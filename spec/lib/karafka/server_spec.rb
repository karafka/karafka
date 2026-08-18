# frozen_string_literal: true

RSpec.describe_current do
  subject(:server_class) { described_class }

  let(:process) { Karafka::App.config.internal.process }
  let(:runner) { Karafka::Runner.new }

  before do
    allow(Karafka::App).to receive_messages(
      run!: nil,
      stopped?: true,
      terminated?: true,
      subscription_groups: { 1 => [] }
    )

    # Do not close the real producer as we use it in specs
    allow(Karafka::App.producer).to receive(:close)
    allow(Karafka::Runner).to receive(:new).and_return(runner)
    allow(runner).to receive(:call)

    jobs_queue = Karafka::Processing::JobsQueue.new

    described_class.listeners = Karafka::Connection::ListenersBatch.new(jobs_queue)
    described_class.workers = instance_double(
      Karafka::Processing::WorkersPool,
      stopped?: true,
      alive: [],
      terminate: nil
    )
  end

  describe "#run" do
    before { allow(process).to receive(:supervise) }

    after do
      server_class.run
      # Since stopping happens in a separate thread, we need to wait
      sleep(0.5)
    end

    it "expect to start supervision" do
      server_class.run
      expect(process).to have_received(:supervise)
    end

    context "when we want to run in supervision" do
      it "runs in supervision, start consuming" do
        expect(process).to receive(:on_sigint)
        expect(process).to receive(:on_sigquit)
        expect(process).to receive(:on_sigterm)
      end
    end

    context "when sigint is received" do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigquit)
        allow(process).to receive(:on_sigterm)
      end

      it "defines a proper action for sigint" do
        expect(described_class).to receive(:stop)
        expect(process).to receive(:on_sigint).and_yield
      end
    end

    context "when sigquit is received" do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigint)
        allow(process).to receive(:on_sigterm)
      end

      it "defines a proper action for sigquit" do
        expect(described_class).to receive(:stop)
        expect(process).to receive(:on_sigquit).and_yield
      end
    end

    context "when sigterm is received" do
      before do
        allow(process).to receive(:supervise)
        allow(process).to receive(:on_sigint)
        allow(process).to receive(:on_sigquit)
      end

      it "defines a proper action for sigterm" do
        expect(described_class).to receive(:stop)
        expect(process).to receive(:on_sigterm).and_yield
      end
    end
  end

  describe "#run without after" do
    context "when server cli options are not valid" do
      let(:expected_error) { Karafka::Errors::InvalidConfigurationError }

      before do
        Karafka::App
          .config
          .internal
          .routing
          .activity_manager
          .include(:topics, "na")
      end

      it "expect to raise proper exception" do
        expect { server_class.run }.to raise_error(expected_error)
      end
    end
  end

  describe "#start" do
    before do
      allow(runner).to receive(:call)

      server_class.start
    end

    it "expect to run" do
      expect(runner).to have_received(:call)
    end
  end

  describe "#stop" do
    let(:original_shutdown_timeout) { Karafka::App.config.shutdown_timeout }

    before do
      # Capture the pristine value before mutating so we can restore it afterwards. Sub-second
      # timeouts used here are lower than the default `max_wait_time`, so leaking them into the
      # global config makes unrelated specs fail validation with a random run order.
      original_shutdown_timeout
      Karafka::App.config.internal.status.run!
      Karafka::App.config.shutdown_timeout = timeout_ms
      # `shutdown_timeout` is memoized on the class via ConfigImporter, so we clear it to ensure
      # each example reads the freshly assigned config value regardless of run order.
      described_class.instance_variable_set(:@shutdown_timeout, nil)
      allow(process).to receive(:supervised?).and_return(true)
    end

    after do
      Karafka::App.config.internal.status.run!
      described_class.workers = instance_double(
        Karafka::Processing::WorkersPool,
        stopped?: true,
        alive: [],
        terminate: nil
      )
      server_class.stop
      # Restore the global config and drop the memoized value so the mutated (possibly sub-second)
      # `shutdown_timeout` does not leak into other specs and break their config validation.
      Karafka::App.config.shutdown_timeout = original_shutdown_timeout
      described_class.instance_variable_set(:@shutdown_timeout, nil)
      # After shutdown we need to reinitialize the app for other specs
      Karafka::App.initialize!
    end

    context "when shutdown time is more then 1" do
      let(:timeout_s) { 15 }
      let(:timeout_ms) { timeout_s * 1_000 }

      before do
        allow(Karafka::App).to receive_messages(
          stopped?: false,
          terminated?: false,
          stop!: nil
        )
        allow(described_class).to receive(:sleep)
        allow(Kernel).to receive(:exit!)
      end

      context "when there are no active threads (all shutdown ok)" do
        before { server_class.stop }

        it "expect stop without exit or sleep" do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).not_to have_received(:sleep)
          expect(Kernel).not_to have_received(:exit!)
        end
      end

      context "when there are active consuming threads (consuming does not want to stop)" do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            stopped?: true,
            terminate: true,
            shutdown: true,
            active?: true
          )
        end

        before do
          described_class.listeners = instance_double(
            Karafka::Connection::ListenersBatch,
            active: [active_thread],
            all?: false,
            select: [active_thread],
            each: nil
          )
          server_class.stop
        end

        it "expect stop and exit with sleep" do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(timeout_s * 10).times
          expect(Kernel).to have_received(:exit!).with(2)
        end
      end

      context "when there are active consuming threads but not supervised" do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            stopped?: false,
            terminate: true,
            shutdown: true,
            active?: true
          )
        end

        before do
          described_class.listeners = instance_double(
            Karafka::Connection::ListenersBatch,
            active: [active_thread],
            all?: false,
            select: [active_thread],
            each: nil
          )

          allow(process).to receive(:supervised?).and_return(false)
          server_class.stop
        end

        it "expect stop and exit with sleep" do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(timeout_s * 10).times
          expect(Kernel).not_to have_received(:exit!)
        end
      end

      context "when there are active processing workers (processing does not want to stop)" do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            alive?: true,
            stopped?: false,
            terminate: true,
            join: true,
            shutdown: true
          )
        end

        before do
          described_class.workers = instance_double(
            Karafka::Processing::WorkersPool,
            stopped?: false,
            alive: [active_thread],
            terminate: nil
          )
          server_class.stop
        end

        it "expect stop and exit with sleep" do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(timeout_s * 10).times
          expect(Kernel).to have_received(:exit!).with(2)
        end
      end
    end

    context "when shutdown time is below 1000ms (sub-second grace)" do
      let(:timeout_ms) { 500 }

      before do
        allow(Karafka::App).to receive_messages(
          stopped?: false,
          terminated?: false,
          stop!: nil
        )
        allow(described_class).to receive(:sleep)
        allow(Kernel).to receive(:exit!)
      end

      context "when there are active consuming threads (consuming does not want to stop)" do
        let(:active_thread) do
          instance_double(
            Karafka::Connection::Listener,
            stopped?: true,
            terminate: true,
            shutdown: true,
            active?: true
          )
        end

        before do
          described_class.listeners = instance_double(
            Karafka::Connection::ListenersBatch,
            active: [active_thread],
            all?: false,
            select: [active_thread],
            each: nil
          )
          server_class.stop
        end

        # Regression: integer division `500 / 1_000` used to floor to 0, giving the supervision
        # loop zero iterations and skipping the grace period entirely (immediate forceful kill).
        # With float math, 500ms / 0.1s supervision sleep must run 5 grace checks.
        it "expect to still grant a grace period instead of collapsing to zero iterations" do
          expect(Karafka::App).to have_received(:stop!)
          expect(described_class).to have_received(:sleep).with(0.1).exactly(5).times
          expect(Kernel).to have_received(:exit!).with(2)
        end
      end
    end
  end

  describe "#quiet" do
    before do
      Karafka::App.public_send(new_status)
      allow(Karafka::App).to receive(:quiet!)
    end

    after { Karafka::App.initialized! }

    context "when stopping" do
      let(:new_status) { :stop! }

      before { allow(Karafka::App).to receive(:stopped?).and_return(false) }

      it do
        described_class.quiet

        expect(Karafka::App).to have_received(:quiet!)
      end
    end

    context "when running" do
      let(:new_status) { :run! }

      before do
        allow(Karafka::App).to receive_messages(
          quieting?: false,
          stopped?: false,
          stopping?: false
        )
      end

      it do
        described_class.quiet

        expect(Karafka::App).to have_received(:quiet!)
      end
    end

    context "when stopped" do
      let(:new_status) { :stopped! }

      it do
        described_class.quiet

        expect(Karafka::App).to have_received(:quiet!)
      end
    end
  end
end

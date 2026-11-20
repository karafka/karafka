# frozen_string_literal: true

require "karafka/instrumentation/vendors/datadog/logger_listener"

# This is fully covered in the integration suite
RSpec.describe_current do
  subject(:listener) { described_class.new }

  let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }
  let(:error) { StandardError.new("test error") }
  let(:active_span) { instance_double("Datadog::Tracing::SpanOperation") }
  let(:dd_client) do
    instance_double(
      "Datadog::Tracing",
      active_span: active_span,
      log_correlation: "dd.trace_id=123"
    )
  end

  before do
    listener.setup do |config|
      config.client = dd_client
    end

    allow(active_span).to receive(:set_error)
    allow(Karafka.logger).to receive(:warn)
    allow(Karafka.logger).to receive(:error)
    allow(Karafka.logger).to receive(:fatal)
    allow(Karafka.logger).to receive(:respond_to?).with(:push_tags).and_return(false)
    allow(Karafka.logger).to receive(:respond_to?).with(:pop_tags).and_return(false)

    trigger
  end

  describe "events mapping" do
    subject(:trigger) { nil }

    it { expect(NotificationsChecker.valid?(listener)).to be(true) }
  end

  describe "#on_error_occurred" do
    subject(:trigger) { listener.on_error_occurred(event) }

    let(:payload) { { error: error, type: type } }

    context "when it is a consumer.initialized.error" do
      let(:type) { "consumer.initialized.error" }
      let(:message) { "Consumer initialized error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.wrap.error" do
      let(:type) { "consumer.wrap.error" }
      let(:message) { "Consumer wrap failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.consume.error" do
      let(:type) { "consumer.consume.error" }
      let(:message) { "Consumer consuming error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.revoked.error" do
      let(:type) { "consumer.revoked.error" }
      let(:message) { "Consumer on revoked failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.idle.error" do
      let(:type) { "consumer.idle.error" }
      let(:message) { "Consumer idle failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.shutdown.error" do
      let(:type) { "consumer.shutdown.error" }
      let(:message) { "Consumer on shutdown failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.tick.error" do
      let(:type) { "consumer.tick.error" }
      let(:message) { "Consumer on tick failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.eofed.error" do
      let(:type) { "consumer.eofed.error" }
      let(:message) { "Consumer on eofed failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a consumer.after_consume.error" do
      let(:type) { "consumer.after_consume.error" }
      let(:message) { "Consumer on after_consume failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a worker.process.error" do
      let(:type) { "worker.process.error" }
      let(:message) { "Worker processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context "when it is a connection.listener.fetch_loop.error" do
      let(:type) { "connection.listener.fetch_loop.error" }
      let(:message) { "Listener fetch loop error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a swarm.supervisor.error" do
      let(:type) { "swarm.supervisor.error" }
      let(:message) { "Swarm supervisor crashed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context "when it is a runner.call.error" do
      let(:type) { "runner.call.error" }
      let(:message) { "Runner crashed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:fatal).with(message) }
    end

    context "when it is an app.stopping.error" do
      let(:type) { "app.stopping.error" }

      let(:payload) do
        {
          type: type,
          error: error,
          caller: nil,
          active_listeners: [],
          alive_workers: []
        }
      end

      let(:message) do
        "Forceful Karafka server stop with: 0 active workers and 0 active listeners"
      end

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a app.forceful_stopping.error" do
      let(:type) { "app.forceful_stopping.error" }
      let(:message) { "Forceful shutdown error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a librdkafka.error" do
      let(:type) { "librdkafka.error" }
      let(:message) { "librdkafka internal error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a callbacks.statistics.error" do
      let(:type) { "callbacks.statistics.error" }
      let(:message) { "callbacks.statistics processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a callbacks.error.error" do
      let(:type) { "callbacks.error.error" }
      let(:message) { "callbacks.error processing failed due to an error: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a connection.client.poll.error" do
      let(:type) { "connection.client.poll.error" }
      let(:message) { "Data polling error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a connection.client.rebalance_callback.error" do
      let(:type) { "connection.client.rebalance_callback.error" }
      let(:message) { "Rebalance callback error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a connection.client.unsubscribe.error" do
      let(:type) { "connection.client.unsubscribe.error" }
      let(:message) { "Client unsubscribe error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a parallel_segments.reducer.error" do
      let(:type) { "parallel_segments.reducer.error" }
      let(:message) { "Parallel segments reducer error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a parallel_segments.partitioner.error" do
      let(:type) { "parallel_segments.partitioner.error" }
      let(:message) { "Parallel segments partitioner error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a virtual_partitions.partitioner.error" do
      let(:type) { "virtual_partitions.partitioner.error" }
      let(:message) { "Virtual partitions partitioner error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:error).with(message) }
    end

    context "when it is a lag_compensation.refresher.error" do
      let(:type) { "lag_compensation.refresher.error" }
      let(:message) { "Lag compensation refresher error occurred: #{error}" }

      it { expect(Karafka.logger).to have_received(:warn).with(message) }
    end

    context "when it is an unrecognized error type" do
      let(:type) { "custom.unknown.error" }
      let(:message) { "custom.unknown.error error occurred: #{error}" }

      it "logs the error without raising UnsupportedCaseError" do
        expect(Karafka.logger).to have_received(:error).with(message)
      end
    end

    context "when active_span is present" do
      let(:type) { "consumer.consume.error" }

      it "sets error on the span" do
        expect(active_span).to have_received(:set_error).with(error)
      end
    end
  end

  describe "#on_worker_process" do
    subject(:trigger) { nil }

    let(:span_class) { Struct.new(:resource) }
    let(:client) do
      span_class = self.span_class

      Class.new do
        define_method(:trace) { |*| span_class.new }
        define_method(:log_correlation) { "" }
      end.new
    end
    # Logging is stubbed on the class so no RSpec double records calls from other threads
    let(:listener_class) do
      Class.new(described_class) do
        attr_reader :logs

        def initialize(...)
          super
          @logs = Queue.new
        end

        private

        def push_tags
        end

        def pop_tags
        end

        def info(message)
          @logs << message
        end
      end
    end
    let(:executor) { Struct.new(:topic).new(Struct.new(:consumer, :name).new("Consumer", "topic")) }
    let(:job_class) do
      job_class = Struct.new(:id, :executor) do
        class << self
          def action
            :consume
          end
        end
      end

      stub_const("DatadogSpecJob", job_class)
    end
    let(:worker_event) do
      Karafka::Core::Monitoring::Event.new("worker.process", { job: job_class.new("id", executor) })
    end

    it "builds the job type once when another worker misses the cache meanwhile" do
      listener = listener_class.new { |config| config.client = client }
      worker_event = self.worker_event
      builds = Queue.new
      other_worker = nil

      job_class.define_singleton_method(:to_s) do
        builds << true

        if builds.size == 1
          other_worker = Thread.new { listener.on_worker_process(worker_event) }
          100.times { other_worker.stop? ? break : sleep(0.01) }
        end

        super()
      end

      listener.on_worker_process(worker_event)
      other_worker.join

      expect(builds.size).to eq(1)
      expect(Array.new(listener.logs.size) { listener.logs.pop }.uniq)
        .to eq(["[id] DatadogSpecJob job for Consumer on topic started"])
    end
  end

  describe "span lifecycle" do
    subject(:trigger) { nil }

    let(:span_class) do
      Class.new do
        attr_accessor :resource
        attr_reader :finishes, :errors

        def initialize
          @finishes = 0
          @errors = []
        end

        def finish
          @finishes += 1
        end

        def set_error(error)
          @errors << error
        end
      end
    end
    # Stands for a span opened by another integration (dd-trace-rb Karafka patch)
    let(:foreign_span) { span_class.new }
    let(:client) do
      span_class = self.span_class
      foreign_span = self.foreign_span

      Class.new do
        attr_reader :spans

        define_method(:initialize) { @spans = [] }
        define_method(:trace) { |*, **| span_class.new.tap { |span| @spans << span } }
        define_method(:active_span) { foreign_span }
        define_method(:log_correlation) { "" }
      end.new
    end
    let(:span_listener) { described_class.new { |config| config.client = client } }
    let(:executor) { Struct.new(:topic).new(Struct.new(:consumer, :name).new("Consumer", "topic")) }
    let(:job_class) do
      job_class = Struct.new(:id, :executor) do
        class << self
          def action
            :consume
          end
        end
      end

      stub_const("DatadogSpanSpecJob", job_class)
    end
    let(:details) { { job: job_class.new("id", executor), time: 1 } }
    let(:own_span) { client.spans.last }

    before do
      allow(Karafka.logger).to receive(:info)
      allow(Karafka.logger).to receive(:warn)
    end

    def instrument(name, payload = details)
      event = Karafka::Core::Monitoring::Event.new(name, payload)
      span_listener.public_send(:"on_#{name.tr(".", "_")}", event)
    end

    context "when job is processed" do
      before do
        instrument("worker.process")
        instrument("worker.processed")
        instrument("worker.completed")
      end

      it "finishes its own span once" do
        expect(own_span.finishes).to eq(1)
      end

      it "does not finish the active span of another integration" do
        expect(foreign_span.finishes).to eq(0)
      end
    end

    context "when wrap fails and worker.processed is not published" do
      before do
        instrument("worker.process")
        instrument("error.occurred", { error: error, type: "consumer.wrap.error" })
        instrument("worker.completed")
      end

      it "finishes its own span on worker.completed" do
        expect(own_span.finishes).to eq(1)
      end

      it "sets the error on its own span" do
        expect(own_span.errors).to eq([error])
        expect(foreign_span.errors).to be_empty
      end
    end

    context "when worker fails and worker.processed is not published" do
      before do
        instrument("worker.process")
        instrument("error.occurred", details.merge(error: error, type: "worker.process.error"))
        instrument("worker.completed")
      end

      it "finishes its own span on worker.completed" do
        expect(own_span.finishes).to eq(1)
      end

      it "sets the error on its own span" do
        expect(own_span.errors).to eq([error])
        expect(foreign_span.errors).to be_empty
      end
    end

    context "when worker.completed is published without a job" do
      before { instrument("worker.completed", { job: nil }) }

      it "does not finish any span" do
        expect(foreign_span.finishes).to eq(0)
      end
    end

    context "when error occurs outside of a job" do
      before do
        instrument("error.occurred", { error: error, type: "connection.client.poll.error" })
      end

      it "sets the error on the active span" do
        expect(foreign_span.errors).to eq([error])
      end
    end

    context "when dd-trace-rb Karafka integration is active" do
      before do
        stub_const(
          "Datadog::Tracing::Contrib::Karafka::Patcher",
          Module.new do
            class << self
              def patch_successful
                true
              end
            end
          end
        )

        2.times do
          instrument("worker.process")
          instrument("worker.processed")
        end
      end

      it "warns once" do
        expect(Karafka.logger).to have_received(:warn).with(/dd-trace-rb Karafka integration/).once
      end
    end

    context "when dd-trace-rb Karafka integration patch failed" do
      before do
        stub_const(
          "Datadog::Tracing::Contrib::Karafka::Patcher",
          Module.new do
            class << self
              def patched?
                true
              end

              def patch_successful
                false
              end
            end
          end
        )

        instrument("worker.process")
      end

      it { expect(Karafka.logger).not_to have_received(:warn) }
    end

    context "when dd-trace-rb Karafka integration is loaded but not active" do
      before do
        stub_const(
          "Datadog::Tracing::Contrib::Karafka::Patcher",
          Module.new do
            class << self
              def patched?
                false
              end

              def patch_successful
                false
              end
            end
          end
        )

        instrument("worker.process")
      end

      it { expect(Karafka.logger).not_to have_received(:warn) }
    end

    context "when dd-trace-rb Karafka integration is not loaded" do
      before { instrument("worker.process") }

      it { expect(Karafka.logger).not_to have_received(:warn) }
    end
  end

  describe "error types coverage" do
    subject(:trigger) { nil }

    it "handles all error types defined in the source code" do
      coverage = ErrorTypesChecker.check_logging_listener_coverage(described_class)

      expect(coverage[:missing]).to be_empty,
        "Datadog logger listener is missing handlers for: #{coverage[:missing].join(", ")}"
    end
  end
end

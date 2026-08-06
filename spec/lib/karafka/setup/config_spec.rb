# frozen_string_literal: true

RSpec.describe_current do
  subject(:config_class) { described_class }

  # Ensure License constant is removed before each test to prevent test pollution
  # This is critical because other tests (like licenser_spec) may define License constants
  # and with random test order, those constants may leak into these tests
  before do
    # rubocop:disable RSpec/RemoveConst
    Karafka.send(:remove_const, :License) if Karafka.const_defined?(:License)
    # rubocop:enable RSpec/RemoveConst
  end

  describe "#setup" do
    it { expect { |block| config_class.setup(&block) }.to yield_with_args }
  end

  describe "#validate!" do
    let(:invalid_configure) do
      lambda do
        Karafka::App.setup do |config|
          config.client_id = nil
        end
      end
    end

    let(:valid_configure) do
      lambda do
        Karafka::App.setup do |config|
          config.client_id = rand(100).to_s
        end
      end
    end

    after { valid_configure.call }

    context "when configuration has errors" do
      let(:error_class) { Karafka::Errors::InvalidConfigurationError }
      let(:error_message) do
        { "config.client_id": "needs to be a string with a Kafka accepted format" }.to_s
      end

      it "raise InvalidConfigurationError exception" do
        expect { invalid_configure.call }.to raise_error do |error|
          expect(error).to be_a(error_class)
          expect(error.message).to eq(error_message)
        end
      end
    end

    context "when configuration is valid" do
      it "not raise InvalidConfigurationError exception" do
        expect { valid_configure.call }.not_to raise_error
      end
    end
  end

  describe "kafka config defaults" do
    subject(:defaults) { Karafka::App.config.kafka }

    let(:expected_defaults) do
      {
        "allow.auto.create.topics": "true",
        "bootstrap.servers": "127.0.0.1:9092",
        "statistics.interval.ms": 5_000,
        "topic.metadata.refresh.interval.ms": 5_000,
        "max.poll.interval.ms": 300_000,
        "client.software.name": "karafka",
        "socket.nagle.disable": true,
        "client.software.version": [
          "v#{Karafka::VERSION}",
          "rdkafka-ruby-v#{Rdkafka::VERSION}",
          "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
        ].join("-")
      }
    end

    it "expect to have correct values after enrichment" do
      Karafka::Setup::DefaultsInjector.consumer(defaults)

      expect(defaults).to eq(expected_defaults)
    end
  end

  describe "pause configuration backwards compatibility" do
    subject(:config) { Karafka::App.config }

    # Ensure clean state before each test
    before do
      Karafka::App.setup do |c|
        # Reset max_timeout first to ensure timeout <= max_timeout constraint is never violated
        c.pause.max_timeout = 30_000
        c.pause.timeout = 1_000
        c.pause.with_exponential_backoff = true
      end
    end

    # Clean up after each test as well
    after do
      Karafka::App.setup do |c|
        # Reset max_timeout first to ensure timeout <= max_timeout constraint is never violated
        c.pause.max_timeout = 30_000
        c.pause.timeout = 1_000
        c.pause.with_exponential_backoff = true
      end
    end

    context "when using new nested API" do
      it "allows setting pause.timeout" do
        Karafka::App.setup do |c|
          c.pause.timeout = 2_000
        end

        expect(config.pause.timeout).to eq(2_000)
      end

      it "allows setting pause.max_timeout" do
        Karafka::App.setup do |c|
          c.pause.max_timeout = 5_000
        end

        expect(config.pause.max_timeout).to eq(5_000)
      end

      it "allows setting pause.with_exponential_backoff" do
        Karafka::App.setup do |c|
          c.pause.with_exponential_backoff = false
        end

        expect(config.pause.with_exponential_backoff).to be(false)
      end
    end
  end

  describe "workers configuration backwards compatibility" do
    subject(:config) { Karafka::App.config }

    after do
      config.workers.concurrency = 5
      config.workers.thread_priority = -1
    end

    context "when using the new nested API" do
      it "allows setting workers.concurrency" do
        config.workers.concurrency = 7

        expect(config.workers.concurrency).to eq(7)
      end

      it "allows setting workers.thread_priority" do
        config.workers.thread_priority = 2

        expect(config.workers.thread_priority).to eq(2)
      end

      it "has the threads backend by default" do
        expect(config.workers.backend).to eq(:threads)
      end

      it "has one carrier thread by default" do
        expect(config.workers.carrier_threads).to eq(1)
      end
    end

    context "when using the deprecated root-level aliases" do
      it "reads concurrency from workers.concurrency" do
        config.workers.concurrency = 9

        expect(config.concurrency).to eq(9)
      end

      it "writes concurrency through to workers.concurrency" do
        config.concurrency = 11

        expect(config.workers.concurrency).to eq(11)
      end

      it "reads worker_thread_priority from workers.thread_priority" do
        config.workers.thread_priority = 3

        expect(config.worker_thread_priority).to eq(3)
      end

      it "writes worker_thread_priority through to workers.thread_priority" do
        config.worker_thread_priority = -2

        expect(config.workers.thread_priority).to eq(-2)
      end

      it "keeps a single source of truth in to_h (no root-level keys)" do
        expect(config.to_h.key?(:concurrency)).to be(false)
        expect(config.to_h.key?(:worker_thread_priority)).to be(false)
        expect(config.to_h.fetch(:workers).key?(:concurrency)).to be(true)
      end
    end
  end

  describe "workers backend resolution" do
    subject(:config) { Karafka::App.config }

    after do
      Karafka::App.setup do |c|
        c.workers.backend = :threads
        c.workers.carrier_threads = 1
      end
    end

    context "when backend is threads (default)" do
      it "uses the threads workers pool" do
        Karafka::App.setup {} # rubocop:disable Lint/EmptyBlock

        expect(config.internal.processing.workers_pool_class)
          .to eq(Karafka::Processing::WorkersPool)
      end
    end

    context "when backend is fibers" do
      it "resolves the fibers workers pool" do
        Karafka::App.setup do |c|
          c.workers.backend = :fibers
        end

        expect(config.internal.processing.workers_pool_class)
          .to eq(Karafka::Processing::WorkersPools::Fibers)
      end

      it "switches back to the threads pool when backend returns to threads" do
        Karafka::App.setup do |c|
          c.workers.backend = :fibers
        end

        Karafka::App.setup do |c|
          c.workers.backend = :threads
        end

        expect(config.internal.processing.workers_pool_class)
          .to eq(Karafka::Processing::WorkersPool)
      end

      it "raises a clear error when the async gem is not available" do
        allow(Karafka::Setup::Config)
          .to receive(:require)
          .with("async")
          .and_raise(LoadError)

        expect do
          Karafka::App.setup do |c|
            c.workers.backend = :fibers
          end
        end.to raise_error(
          Karafka::Errors::DependencyConstraintsError,
          /requires the `async` gem/
        )
      end
    end

    context "when a custom workers pool class is configured explicitly" do
      let(:custom_pool) { Class.new(Karafka::Processing::WorkersPool) }

      after do
        Karafka::App.setup do |c|
          c.internal.processing.workers_pool_class = Karafka::Processing::WorkersPool
        end
      end

      it "is not overwritten by the backend resolution" do
        custom = custom_pool

        Karafka::App.setup do |c|
          c.workers.backend = :fibers
          c.internal.processing.workers_pool_class = custom
        end

        expect(config.internal.processing.workers_pool_class).to eq(custom)
      end
    end
  end

  describe "producer configuration block" do
    subject(:config) { Karafka::App.config }

    after do
      # Reset to clean state
      Karafka::App.setup do |c|
        c.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
      end
    end

    context "when producer block is provided" do
      it "executes the block with producer config after setup" do
        received_config = nil

        Karafka::App.setup do |c|
          c.producer do |producer_config|
            received_config = producer_config
          end
        end

        # Block should have been called with WaterDrop config
        expect(received_config).not_to be_nil
        expect(received_config).to respond_to(:kafka)
        expect(received_config).to respond_to(:logger)
      end

      it "allows customizing producer kafka settings" do
        Karafka::App.setup do |c|
          c.producer do |producer_config|
            producer_config.kafka[:"compression.type"] = "snappy"
            producer_config.kafka[:"linger.ms"] = 10
          end
        end

        # Verify the settings were applied
        expect(config.producer.config.kafka[:"compression.type"]).to eq("snappy")
        expect(config.producer.config.kafka[:"linger.ms"]).to eq(10)
      end

      it "allows adding middleware to producer" do
        test_middleware = Class.new do
          def call(message)
            message
          end
        end

        Karafka::App.setup do |c|
          c.producer do |producer_config|
            producer_config.middleware.append(test_middleware.new)
          end
        end

        # Verify middleware works by running a test message through it
        # We use the producer's internal middleware to transform a message
        result = config.producer.middleware.run({ topic: "test" })
        expect(result).to be_a(Hash)
      end
    end

    context "when producer block is not provided" do
      it "creates default producer without errors" do
        Karafka::App.setup do |c|
          c.kafka = { "bootstrap.servers": "127.0.0.1:9092" }
        end

        expect(config.producer).not_to be_nil
      end
    end

    context "when custom producer is set via assignment" do
      it "preserves custom producer assignment" do
        custom_producer = WaterDrop::Producer.new do |c|
          c.kafka = { "bootstrap.servers": "custom.server:9092" }
        end

        Karafka::App.setup do |c|
          c.producer = custom_producer
        end

        # Custom producer should be used
        expect(config.producer).to eq(custom_producer)
      end
    end

    context "when both custom producer and configuration block are used" do
      it "applies block to custom producer" do
        custom_producer = WaterDrop::Producer.new do |c|
          c.kafka = { "bootstrap.servers": "custom.server:9092" }
        end

        Karafka::App.setup do |c|
          c.producer = custom_producer

          c.producer do |producer_config|
            producer_config.kafka[:"compression.type"] = "gzip"
          end
        end

        # Custom producer should still be used
        expect(config.producer).to eq(custom_producer)
        # Block should have been applied to the custom producer
        expect(config.producer.config.kafka[:"compression.type"]).to eq("gzip")
      end
    end
  end
end

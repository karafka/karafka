# frozen_string_literal: true

RSpec.describe_current do
  subject(:config_class) { described_class }

  describe '#setup' do
    it { expect { |block| config_class.setup(&block) }.to yield_with_args }
  end

  describe '#validate!' do
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

    context 'when configuration has errors' do
      let(:error_class) { Karafka::Errors::InvalidConfigurationError }
      let(:error_message) do
        { 'config.client_id': 'needs to be a string with a Kafka accepted format' }.to_s
      end

      it 'raise InvalidConfigurationError exception' do
        expect { invalid_configure.call }.to raise_error do |error|
          expect(error).to be_a(error_class)
          expect(error.message).to eq(error_message)
        end
      end
    end

    context 'when configuration is valid' do
      it 'not raise InvalidConfigurationError exception' do
        expect { valid_configure.call }.not_to raise_error
      end
    end
  end

  describe 'kafka config defaults' do
    subject(:defaults) { Karafka::App.config.kafka }

    let(:expected_defaults) do
      {
        'allow.auto.create.topics': 'true',
        'bootstrap.servers': '127.0.0.1:9092',
        'statistics.interval.ms': 5_000,
        'topic.metadata.refresh.interval.ms': 5_000,
        'max.poll.interval.ms': 300_000,
        'client.software.name': 'karafka',
        'socket.nagle.disable': true,
        'client.software.version': [
          "v#{Karafka::VERSION}",
          "rdkafka-ruby-v#{Rdkafka::VERSION}",
          "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
        ].join('-')
      }
    end

    it 'expect to have correct values after enrichment' do
      Karafka::Setup::DefaultsInjector.consumer(defaults)

      expect(defaults).to eq(expected_defaults)
    end
  end

  describe 'pause configuration backwards compatibility' do
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

    context 'when using new nested API' do
      it 'allows setting pause.timeout' do
        Karafka::App.setup do |c|
          c.pause.timeout = 2_000
        end

        expect(config.pause.timeout).to eq(2_000)
      end

      it 'allows setting pause.max_timeout' do
        Karafka::App.setup do |c|
          c.pause.max_timeout = 5_000
        end

        expect(config.pause.max_timeout).to eq(5_000)
      end

      it 'allows setting pause.with_exponential_backoff' do
        Karafka::App.setup do |c|
          c.pause.with_exponential_backoff = false
        end

        expect(config.pause.with_exponential_backoff).to be(false)
      end
    end

    context 'when using old flat API via config instance' do
      it 'allows reading pause_timeout via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause.timeout = 3_000
        end

        expect(config.pause_timeout).to eq(3_000)
      end

      it 'allows setting pause_timeout via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause_timeout = 4_000
        end

        expect(config.pause.timeout).to eq(4_000)
        expect(config.pause_timeout).to eq(4_000)
      end

      it 'allows reading pause_max_timeout via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause.max_timeout = 7_000
        end

        expect(config.pause_max_timeout).to eq(7_000)
      end

      it 'allows setting pause_max_timeout via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause_max_timeout = 8_000
        end

        expect(config.pause.max_timeout).to eq(8_000)
        expect(config.pause_max_timeout).to eq(8_000)
      end

      it 'allows reading pause_with_exponential_backoff via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause.with_exponential_backoff = false
        end

        expect(config.pause_with_exponential_backoff).to be(false)
      end

      it 'allows setting pause_with_exponential_backoff via backwards compatible method' do
        Karafka::App.setup do |c|
          c.pause_with_exponential_backoff = false
        end

        expect(config.pause.with_exponential_backoff).to be(false)
        expect(config.pause_with_exponential_backoff).to be(false)
      end
    end

    context 'when mixing old and new APIs' do
      it 'reflects changes from old API setter in new API getter' do
        Karafka::App.setup do |c|
          c.pause_timeout = 5_000
        end

        expect(config.pause.timeout).to eq(5_000)
      end

      it 'reflects changes from new API setter in old API getter' do
        Karafka::App.setup do |c|
          c.pause.timeout = 6_000
        end

        expect(config.pause_timeout).to eq(6_000)
      end
    end
  end

  describe 'producer configuration block' do
    subject(:config) { Karafka::App.config }

    after do
      # Reset to clean state
      Karafka::App.setup do |c|
        c.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
      end
    end

    context 'when producer block is provided' do
      it 'executes the block with producer config after setup' do
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

      it 'allows customizing producer kafka settings' do
        Karafka::App.setup do |c|
          c.producer do |producer_config|
            producer_config.kafka[:'compression.type'] = 'snappy'
            producer_config.kafka[:'linger.ms'] = 10
          end
        end

        # Verify the settings were applied
        expect(config.producer.config.kafka[:'compression.type']).to eq('snappy')
        expect(config.producer.config.kafka[:'linger.ms']).to eq(10)
      end

      it 'allows adding middleware to producer' do
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
        result = config.producer.middleware.run({ topic: 'test' })
        expect(result).to be_a(Hash)
      end
    end

    context 'when producer block is not provided' do
      it 'creates default producer without errors' do
        Karafka::App.setup do |c|
          c.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
        end

        expect(config.producer).not_to be_nil
      end
    end

    context 'when custom producer is set via assignment' do
      it 'preserves custom producer assignment' do
        custom_producer = WaterDrop::Producer.new do |c|
          c.kafka = { 'bootstrap.servers': 'custom.server:9092' }
        end

        Karafka::App.setup do |c|
          c.producer = custom_producer
        end

        # Custom producer should be used
        expect(config.producer).to eq(custom_producer)
      end
    end

    context 'when both custom producer and configuration block are used' do
      it 'applies block to custom producer' do
        custom_producer = WaterDrop::Producer.new do |c|
          c.kafka = { 'bootstrap.servers': 'custom.server:9092' }
        end

        Karafka::App.setup do |c|
          c.producer = custom_producer

          c.producer do |producer_config|
            producer_config.kafka[:'compression.type'] = 'gzip'
          end
        end

        # Custom producer should still be used
        expect(config.producer).to eq(custom_producer)
        # Block should have been applied to the custom producer
        expect(config.producer.config.kafka[:'compression.type']).to eq('gzip')
      end
    end
  end
end

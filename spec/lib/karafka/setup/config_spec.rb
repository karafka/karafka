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
end

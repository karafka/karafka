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
      let(:error_class) { ::Karafka::Errors::InvalidConfigurationError }
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
        'bootstrap.servers': kafka_bootstrap_servers,
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
end

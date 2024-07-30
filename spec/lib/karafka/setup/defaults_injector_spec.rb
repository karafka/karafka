# frozen_string_literal: true

RSpec.describe_current do
  subject(:injector) { described_class }

  let(:kafka_config) { {} }

  describe '#consumer' do
    context 'when in production environment' do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(true)
        injector.consumer(kafka_config)
      end

      it 'adds only consumer kafka defaults' do
        expect(kafka_config).to include(
          'statistics.interval.ms': 5_000,
          'client.software.name': 'karafka',
          'max.poll.interval.ms': 300_000,
          'client.software.version': [
            "v#{Karafka::VERSION}",
            "rdkafka-ruby-v#{Rdkafka::VERSION}",
            "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
          ].join('-')
        )
      end

      it 'does not add consumer kafka dev defaults' do
        expect(kafka_config).not_to include(
          'allow.auto.create.topics': 'true',
          'topic.metadata.refresh.interval.ms': 5_000
        )
      end
    end

    context 'when not in production environment' do
      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.consumer(kafka_config)
      end

      it 'adds both consumer kafka defaults and dev defaults' do
        expect(kafka_config).to include(
          'statistics.interval.ms': 5_000,
          'client.software.name': 'karafka',
          'max.poll.interval.ms': 300_000,
          'client.software.version': [
            "v#{Karafka::VERSION}",
            "rdkafka-ruby-v#{Rdkafka::VERSION}",
            "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
          ].join('-'),
          'allow.auto.create.topics': 'true',
          'topic.metadata.refresh.interval.ms': 5_000
        )
      end
    end

    context 'when defaults are already present in kafka_config' do
      let(:kafka_config) do
        {
          'statistics.interval.ms': 10_000,
          'client.software.name': 'custom_name',
          'max.poll.interval.ms': 200_000,
          'client.software.version': 'custom_version',
          'allow.auto.create.topics': 'false',
          'topic.metadata.refresh.interval.ms': 10_000
        }
      end

      before do
        allow(Karafka::App.env).to receive(:production?).and_return(false)
        injector.consumer(kafka_config)
      end

      it 'does not overwrite existing settings' do
        expect(kafka_config).to eq(
          'statistics.interval.ms': 10_000,
          'client.software.name': 'custom_name',
          'max.poll.interval.ms': 200_000,
          'client.software.version': 'custom_version',
          'allow.auto.create.topics': 'false',
          'topic.metadata.refresh.interval.ms': 10_000
        )
      end
    end
  end
end

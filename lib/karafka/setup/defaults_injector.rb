# frozen_string_literal: true

module Karafka
  module Setup
    # Injector that enriches each Kafka cluster with needed defaults. User may use more than one
    # cluster and define them on a per-topic basis. We use this when we build the final config
    # per subscription group.
    module DefaultsInjector
      # Defaults for kafka settings, that will be overwritten only if not present already
      CONSUMER_KAFKA_DEFAULTS = {
        # We emit the statistics by default, so all the instrumentation and web-ui work out of
        # the box, without requiring users to take any extra actions aside from enabling.
        'statistics.interval.ms': 5_000,
        'client.software.name': 'karafka',
        # Same as librdkafka default, we inject it nonetheless to have it always available as
        # some features may use this value for computation and it is better to ensure, we do
        # always have it
        'max.poll.interval.ms': 300_000,
        'client.software.version': [
          "v#{Karafka::VERSION}",
          "rdkafka-ruby-v#{Rdkafka::VERSION}",
          "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
        ].join('-')
      }.freeze

      # Contains settings that should not be used in production but make life easier in dev
      CONSUMER_KAFKA_DEV_DEFAULTS = {
        # Will create non-existing topics automatically.
        # Note that the broker needs to be configured with `auto.create.topics.enable=true`
        # While it is not recommended in prod, it simplifies work in dev
        'allow.auto.create.topics': 'true',
        # We refresh the cluster state often as newly created topics in dev may not be detected
        # fast enough. Fast enough means within reasonable time to provide decent user experience
        # While it's only a one time thing for new topics, it can still be irritating to have to
        # restart the process.
        'topic.metadata.refresh.interval.ms': 5_000
      }.freeze

      private_constant :CONSUMER_KAFKA_DEFAULTS, :CONSUMER_KAFKA_DEV_DEFAULTS

      class << self
        # Propagates the kafka setting defaults unless they are already present for consumer config
        # This makes it easier to set some values that users usually don't change but still allows
        # them to overwrite the whole hash if they want to
        # @param kafka_config [Hash] kafka scoped config
        def consumer(kafka_config)
          CONSUMER_KAFKA_DEFAULTS.each do |key, value|
            next if kafka_config.key?(key)

            kafka_config[key] = value
          end

          return if Karafka::App.env.production?

          CONSUMER_KAFKA_DEV_DEFAULTS.each do |key, value|
            next if kafka_config.key?(key)

            kafka_config[key] = value
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Setup
    # Injector that enriches each Kafka cluster with needed defaults. User may use more than one
    # cluster and define them on a per-topic basis. We use this when we build the final config
    # per subscription group.
    module DefaultsInjector
      # Client software version string reported to Kafka by all the clients we build
      CLIENT_SOFTWARE_VERSION = [
        "v#{Karafka::VERSION}",
        "rdkafka-ruby-v#{Rdkafka::VERSION}",
        "librdkafka-v#{Rdkafka::LIBRDKAFKA_VERSION}"
      ].join("-").freeze

      # Defaults for consumer-group kafka settings, that will be overwritten only if not present
      # already
      CONSUMER_KAFKA_DEFAULTS = {
        # We emit the statistics by default, so all the instrumentation and web-ui work out of
        # the box, without requiring users to take any extra actions aside from enabling.
        "statistics.interval.ms": 5_000,
        "client.software.name": "karafka",
        # Same as librdkafka default, we inject it nonetheless to have it always available as
        # some features may use this value for computation and it is better to ensure, we do
        # always have it
        "max.poll.interval.ms": 300_000,
        "socket.nagle.disable": true,
        "client.software.version": CLIENT_SOFTWARE_VERSION
      }.freeze

      # Contains settings that should not be used in production but make life easier in dev
      CONSUMER_KAFKA_DEV_DEFAULTS = {
        # Will create non-existing topics automatically.
        # Note that the broker needs to be configured with `auto.create.topics.enable=true`
        # While it is not recommended in prod, it simplifies work in dev
        "allow.auto.create.topics": "true",
        # We refresh the cluster state often as newly created topics in dev may not be detected
        # fast enough. Fast enough means within reasonable time to provide decent user experience
        # While it's only a one time thing for new topics, it can still be irritating to have to
        # restart the process.
        "topic.metadata.refresh.interval.ms": 5_000
      }.freeze

      # Defaults for share-group (KIP-932) kafka settings. They mirror the consumer-group ones
      # minus the properties that do not apply to share consumers: `max.poll.interval.ms` is a
      # consumer-group liveness property (share consumers use broker-side record acquisition
      # locks instead of poll-based liveness), so it is not injected here.
      SHARE_GROUP_KAFKA_DEFAULTS = {
        "statistics.interval.ms": 5_000,
        "client.software.name": "karafka",
        "socket.nagle.disable": true,
        "client.software.version": CLIENT_SOFTWARE_VERSION
      }.freeze

      # Dev-only share-group defaults. Same rationale as for the consumer-group ones.
      SHARE_GROUP_KAFKA_DEV_DEFAULTS = {
        "allow.auto.create.topics": "true",
        "topic.metadata.refresh.interval.ms": 5_000
      }.freeze

      # Contains settings that should not be used in production but make life easier in dev
      # It is applied only to the default producer. If users setup their own producers, then
      # they have to set this by themselves.
      PRODUCER_KAFKA_DEV_DEFAULTS = {
        # For all of those same reasoning as for the consumer
        "allow.auto.create.topics": "true",
        "topic.metadata.refresh.interval.ms": 5_000,
        "socket.nagle.disable": true
      }.freeze

      private_constant(
        :CLIENT_SOFTWARE_VERSION,
        :CONSUMER_KAFKA_DEFAULTS, :CONSUMER_KAFKA_DEV_DEFAULTS,
        :SHARE_GROUP_KAFKA_DEFAULTS, :SHARE_GROUP_KAFKA_DEV_DEFAULTS,
        :PRODUCER_KAFKA_DEV_DEFAULTS
      )

      # Injects the consumer-group kafka defaults into a kafka config hash, adding the dev-only
      # ones outside of production. Extensions (e.g. Pro) layer extra defaults by prepending onto
      # the module singleton class and calling `super`.
      class ConsumerGroup < Karafka::Core::Configurable::Injector
        class << self
          # @return [Hash] consumer-group kafka defaults for the current environment
          def defaults
            return CONSUMER_KAFKA_DEFAULTS if Karafka::App.env.production?

            CONSUMER_KAFKA_DEFAULTS.merge(CONSUMER_KAFKA_DEV_DEFAULTS)
          end
        end
      end

      # Injects the share-group (KIP-932) kafka defaults into a kafka config hash, adding the
      # dev-only ones outside of production.
      class ShareGroup < Karafka::Core::Configurable::Injector
        class << self
          # @return [Hash] share-group kafka defaults for the current environment
          def defaults
            return SHARE_GROUP_KAFKA_DEFAULTS if Karafka::App.env.production?

            SHARE_GROUP_KAFKA_DEFAULTS.merge(SHARE_GROUP_KAFKA_DEV_DEFAULTS)
          end
        end
      end

      # Injects the producer kafka defaults into a kafka config hash. They are dev-only, so nothing
      # is injected in production.
      class Producer < Karafka::Core::Configurable::Injector
        class << self
          # @return [Hash] producer kafka defaults for the current environment
          def defaults
            return super if Karafka::App.env.production?

            PRODUCER_KAFKA_DEV_DEFAULTS
          end
        end
      end

      class << self
        # Kafka settings that are managed internally by Karafka and should not be set directly
        # by users. Setting them manually may cause misbehaviours and other unexpected issues.
        #
        # @return [Set<Symbol>] set of managed kafka setting keys
        def managed_keys
          @managed_keys ||= Set[
            :"statistics.unassigned.include"
          ]
        end

        # Propagates the kafka setting defaults unless they are already present for a
        # consumer-group consumer config. This makes it easier to set some values that users
        # usually don't change but still allows them to overwrite the whole hash if they want to
        # @param kafka_config [Hash] kafka scoped config
        def consumer_group(kafka_config)
          ConsumerGroup.call(kafka_config)
        end

        # Legacy alias for {.consumer_group}. Kept for backwards compatibility. Delegates through
        # the canonical method so extensions layering on top of `consumer_group` (via singleton
        # class prepends) keep intercepting regardless of the entry point.
        # @param kafka_config [Hash] kafka scoped config
        def consumer(kafka_config)
          consumer_group(kafka_config)
        end

        # Propagates the kafka setting defaults unless they are already present for a share-group
        # (KIP-932) consumer config
        # @param kafka_config [Hash] kafka scoped config
        def share_group(kafka_config)
          ShareGroup.call(kafka_config)
        end

        # Propagates the kafka settings defaults unless they are already present for producer
        # config. This makes it easier to set some values that users usually don't change but still
        # allows them to overwrite the whole hash.
        #
        # @param kafka_config [Hash] kafka scoped config
        def producer(kafka_config)
          Producer.call(kafka_config)
        end
      end
    end
  end
end

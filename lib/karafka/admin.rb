# frozen_string_literal: true

module Karafka
  # Admin actions that we can perform via Karafka on our Kafka cluster
  #
  # @note It always initializes a new admin instance as we want to ensure it is always closed
  #   Since admin actions are not performed that often, that should be ok.
  #
  # @note It always uses the primary defined cluster and does not support multi-cluster work.
  #   Cluster on which operations are performed can be changed via `admin.kafka` config, however
  #   there is no multi-cluster runtime support.
  class Admin
    extend Core::Helpers::Time

    extend Helpers::ConfigImporter.new(
      max_wait_time: %i[admin max_wait_time],
      poll_timeout: %i[admin poll_timeout],
      max_retries_duration: %i[admin max_retries_duration],
      retry_backoff: %i[admin retry_backoff],
      group_id: %i[admin group_id],
      app_kafka: %i[kafka],
      admin_kafka: %i[admin kafka]
    )

    class << self
      # Delegate topic-related operations to Topics class

      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer, Time] offset from which we should start
      # @param settings [Hash] kafka extra settings
      # @see Topics.read
      def read_topic(name, partition, count, start_offset = -1, settings = {})
        Topics.read(name, partition, count, start_offset, settings)
      end

      # @param name [String] topic name
      # @param partitions [Integer] number of partitions we expect
      # @param replication_factor [Integer] number of replicas
      # @param topic_config [Hash] topic config details
      # @see Topics.create
      def create_topic(name, partitions, replication_factor, topic_config = {})
        Topics.create(name, partitions, replication_factor, topic_config)
      end

      # @param name [String] topic name
      # @see Topics.delete
      def delete_topic(name)
        Topics.delete(name)
      end

      # @param name [String] topic name
      # @param partitions [Integer] total number of partitions we expect to end up with
      # @see Topics.create_partitions
      def create_partitions(name, partitions)
        Topics.create_partitions(name, partitions)
      end

      # @param name_or_hash [String, Symbol, Hash] topic name or hash with topics and partitions
      # @param partition [Integer, nil] partition (nil when using hash format)
      # @see Topics.read_watermark_offsets
      def read_watermark_offsets(name_or_hash, partition = nil)
        Topics.read_watermark_offsets(name_or_hash, partition)
      end

      # @param topic_name [String] name of the topic we're interested in
      # @see Topics.info
      def topic_info(topic_name)
        Topics.info(topic_name)
      end

      # @param consumer_group_id [String] id of the consumer group for which we want to move the
      #   existing offset
      # @param topics_with_partitions_and_offsets [Hash] Hash with list of topics and settings
      # @see ConsumerGroups.seek
      def seek_consumer_group(consumer_group_id, topics_with_partitions_and_offsets)
        ConsumerGroups.seek(consumer_group_id, topics_with_partitions_and_offsets)
      end

      # Takes consumer group and its topics and copies all the offsets to a new named group
      #
      # @param previous_name [String] old consumer group name
      # @param new_name [String] new consumer group name
      # @param topics [Array<String>] topics for which we want to migrate offsets during rename
      # @return [Boolean] true if anything was migrated, otherwise false
      # @see ConsumerGroups.copy
      def copy_consumer_group(previous_name, new_name, topics)
        ConsumerGroups.copy(previous_name, new_name, topics)
      end

      # Takes consumer group and its topics and migrates all the offsets to a new named group
      #
      # @param previous_name [String] old consumer group name
      # @param new_name [String] new consumer group name
      # @param topics [Array<String>] topics for which we want to migrate offsets during rename
      # @param delete_previous [Boolean] should we delete previous consumer group after rename.
      #   Defaults to true.
      # @return [Boolean] true if rename (and optionally removal) was ok or false if there was
      #   nothing really to rename
      # @see ConsumerGroups.rename
      def rename_consumer_group(previous_name, new_name, topics, delete_previous: true)
        ConsumerGroups.rename(previous_name, new_name, topics, delete_previous: delete_previous)
      end

      # Removes given consumer group (if exists)
      #
      # @param consumer_group_id [String] consumer group name
      # @see ConsumerGroups.delete
      def delete_consumer_group(consumer_group_id)
        ConsumerGroups.delete(consumer_group_id)
      end

      # Triggers a rebalance for the specified consumer group
      #
      # @param consumer_group_id [String] consumer group id to trigger rebalance for
      # @see ConsumerGroups.trigger_rebalance
      # @note This API should be used only for development.
      def trigger_rebalance(consumer_group_id)
        ConsumerGroups.trigger_rebalance(consumer_group_id)
      end

      # Reads lags and offsets for given topics in the context of consumer groups defined in the
      #   routing
      # @param consumer_groups_with_topics [Hash<String, Array<String>>] hash with consumer groups
      #   names with array of topics to query per consumer group inside
      # @param active_topics_only [Boolean] if set to false, when we use routing topics, will
      #   select also topics that are marked as inactive in routing
      # @return [Hash<String, Hash<Integer, <Hash<Integer>>>>] hash where the top level keys are
      #   the consumer groups and values are hashes with topics and inside partitions with lags
      #   and offsets
      # @see ConsumerGroups.read_lags_with_offsets
      def read_lags_with_offsets(consumer_groups_with_topics = {}, active_topics_only: true)
        ConsumerGroups.read_lags_with_offsets(
          consumer_groups_with_topics,
          active_topics_only: active_topics_only
        )
      end

      # Plans a replication factor increase for a topic that can be used with Kafka's
      # reassignment tools. Since librdkafka does not support increasing replication factor
      # directly, this method generates the necessary JSON and commands for manual execution.
      #
      # @param topic [String] name of the topic to plan replication for
      # @param replication_factor [Integer] target replication factor (must be higher than current)
      # @param brokers [Hash<Integer, Array<Integer>>] optional manual broker assignments
      #   per partition. Keys are partition IDs, values are arrays of broker IDs. If not provided,
      #   assignments distribution will happen automatically.
      # @return [Replication] plan object with JSON, commands, and instructions
      #
      # @example Plan replication increase with automatic broker distribution
      #   plan = Karafka::Admin.plan_topic_replication(topic: 'events', replication_factor: 3)
      #
      #   # Review the plan
      #   puts plan.summary
      #
      #   # Export JSON for Kafka's reassignment tools
      #   plan.export_to_file('reassignment.json')
      #
      #   # Execute the plan (replace <KAFKA_BROKERS> with actual brokers)
      #   system(plan.execution_commands[:execute].gsub('<KAFKA_BROKERS>', 'localhost:9092'))
      #
      # @example Plan replication with manual broker placement - specify brokers
      #   plan = Karafka::Admin.plan_topic_replication(
      #     topic: 'events',
      #     replication_factor: 3,
      #     brokers: {
      #       0 => [1, 2, 4],  # Partition 0 on brokers 1, 2, 4
      #       1 => [2, 3, 4],  # Partition 1 on brokers 2, 3, 4
      #       2 => [1, 3, 5]   # Partition 2 on brokers 1, 3, 5
      #     }
      #   )
      #
      #   # The plan will use your exact broker specifications
      #   puts plan.partitions_assignment
      #   # => { 0=>[1, 2, 4], 1=>[2, 3, 4], 2=>[1, 3, 5] }
      #
      # @see Replication.plan for more details
      def plan_topic_replication(topic:, replication_factor:, brokers: nil)
        Replication.plan(
          topic: topic,
          to: replication_factor,
          brokers: brokers
        )
      end

      # @return [Rdkafka::Metadata] cluster metadata info
      def cluster_info
        with_admin(&:metadata)
      end

      # Creates consumer instance and yields it. After usage it closes the consumer instance
      # This API can be used in other pieces of code and allows for low-level consumer usage
      #
      # @param settings [Hash] extra settings to customize consumer
      #
      # @note We always ship and yield a proxied consumer because admin API performance is not
      #   that relevant. That is, there are no high frequency calls that would have to be delegated
      def with_consumer(settings = {})
        bind_id = SecureRandom.uuid

        consumer = config(:consumer, settings).consumer(native_kafka_auto_start: false)
        bind_oauth(bind_id, consumer)

        consumer.start
        proxy = ::Karafka::Connection::Proxy.new(consumer)
        yield(proxy)
      ensure
        # Always unsubscribe consumer just to be sure, that no metadata requests are running
        # when we close the consumer. This in theory should prevent from some race-conditions
        # that originate from librdkafka
        begin
          consumer&.unsubscribe
        # Ignore any errors and continue to close consumer despite them
        rescue Rdkafka::RdkafkaError
          nil
        end

        consumer&.close

        unbind_oauth(bind_id)
      end

      # Creates admin instance and yields it. After usage it closes the admin instance
      def with_admin
        bind_id = SecureRandom.uuid

        admin = config(:producer, {}).admin(
          native_kafka_auto_start: false,
          native_kafka_poll_timeout_ms: poll_timeout
        )

        bind_oauth(bind_id, admin)

        admin.start
        proxy = ::Karafka::Connection::Proxy.new(admin)
        yield(proxy)
      ensure
        admin&.close

        unbind_oauth(bind_id)
      end

      private

      # @return [Integer] number of seconds to wait. `rdkafka` requires this value
      #   (`max_wait_time`) to be provided in seconds while we define it in ms hence the conversion
      def max_wait_time_seconds
        max_wait_time / 1_000.0
      end

      # Adds a new callback for given rdkafka instance for oauth token refresh (if needed)
      #
      # @param id [String, Symbol] unique (for the lifetime of instance) id that we use for
      #   callback referencing
      # @param instance [Rdkafka::Consumer, Rdkafka::Admin] rdkafka instance to be used to set
      #   appropriate oauth token when needed
      def bind_oauth(id, instance)
        ::Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.add(
          id,
          Instrumentation::Callbacks::OauthbearerTokenRefresh.new(
            instance
          )
        )
      end

      # Removes the callback from no longer used instance
      #
      # @param id [String, Symbol] unique (for the lifetime of instance) id that we use for
      #   callback referencing
      def unbind_oauth(id)
        ::Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(id)
      end

      # There are some cases where rdkafka admin operations finish successfully but without the
      # callback being triggered to materialize the post-promise object. Until this is fixed we
      # can figure out, that operation we wanted to do finished successfully by checking that the
      # effect of the command (new topic, more partitions, etc) is handled. Exactly for that we
      # use the breaker. It we get a timeout, we can check that what we wanted to achieve has
      # happened via the breaker check, hence we do not need to wait any longer.
      #
      # @param handler [Proc] the wait handler operation
      # @param breaker [Proc] extra condition upon timeout that indicates things were finished ok
      def with_re_wait(handler, breaker)
        start_time = monotonic_now
        # Convert milliseconds to seconds for sleep
        sleep_time = retry_backoff / 1000.0

        loop do
          handler.call

          sleep(sleep_time)

          return if breaker.call
        rescue Rdkafka::AbstractHandle::WaitTimeoutError
          return if breaker.call

          next if monotonic_now - start_time < max_retries_duration

          raise(Errors::ResultNotVisibleError)
        end
      end

      # @param type [Symbol] type of config we want
      # @param settings [Hash] extra settings for config (if needed)
      # @return [::Rdkafka::Config] rdkafka config
      def config(type, settings)
        app_kafka
          .then(&:dup)
          .merge(admin_kafka)
          .tap { |config| config[:'group.id'] = group_id }
          # We merge after setting the group id so it can be altered if needed
          # In general in admin we only should alter it when we need to impersonate a given
          # consumer group or do something similar
          .merge!(settings)
          .then { |config| Karafka::Setup::AttributesMap.public_send(type, config) }
          .then { |config| ::Rdkafka::Config.new(config) }
      end
    end
  end
end

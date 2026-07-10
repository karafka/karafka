# frozen_string_literal: true

module Karafka
  # Admin actions that we can perform via Karafka on our Kafka cluster
  #
  # @note It always initializes a new admin instance as we want to ensure it is always closed
  #   Since admin actions are not performed that often, that should be ok.
  #
  # @note By default it uses the primary defined cluster. For multi-cluster operations, create
  #   an Admin instance with custom kafka configuration:
  #   `Karafka::Admin.new(kafka: { 'bootstrap.servers': 'other:9092' })`
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

    # Creates a new Admin instance
    #
    # @param kafka [Hash] custom kafka configuration to merge with app defaults.
    #   Useful for multi-cluster operations where you want to target a different cluster.
    # @param external_client [Object, nil] active rdkafka client (raw or wrapped with
    #   `Karafka::Connection::Proxy`) on which admin operations should run, instead of each
    #   operation creating its own short-lived instance. Routing is capability based: rdkafka
    #   admin instances are used by admin-based operations (`with_admin` and everything built
    #   on top of it, e.g. `cluster_info`), any other external client is used by consumer-based
    #   operations (`with_consumer` and everything built on top of it). The lifecycle of a
    #   external client belongs fully to its owner: it is never configured, started or closed
    #   here and all operations run within its identity, including its `group.id`. This is a
    #   low-level internal API: the caller is responsible for providing a client capable of
    #   the invoked operations and for invoking only operations that are safe to run on a
    #   live client.
    #
    # @example Create admin for a different cluster
    #   admin = Karafka::Admin.new(kafka: { 'bootstrap.servers': 'other-cluster:9092' })
    #   admin.cluster_info
    #
    # @example Read lags of a running consumer via its own client connection
    #   admin = Karafka::Admin.new(external_client: client)
    #   admin.read_lags_with_offsets({ 'my-group' => ['events'] })
    def initialize(kafka: {}, external_client: nil)
      @custom_kafka = kafka
      @external_client = external_client
    end

    # No-op close to normalize the API surface.
    #
    # Each admin operation currently opens and closes its own underlying rdkafka admin instance
    # internally, so there is nothing to release at the `Karafka::Admin` level right now. This
    # method exists so that callers who hold an instance and call `#close` on it (matching the
    # pattern of other closeable resources) do not raise `NoMethodError`.
    #
    # In the future, `Karafka::Admin` is planned to be refactored to reuse a single rdkafka admin
    # instance across multiple operations rather than creating and tearing one down per call. When
    # that happens, this method will need to release that shared instance. The no-op is here now
    # so that all callers are already written against the correct API and require no changes when
    # the real implementation lands.
    def close
    end

    class << self
      # Delegate topic-related operations to Topics class

      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer, Time] offset from which we should start
      # @param settings [Hash] kafka extra settings
      # @see Topics.read
      def read_topic(name, partition, count, start_offset = -1, settings = {})
        new.read_topic(name, partition, count, start_offset, settings)
      end

      # @param name [String] topic name
      # @param partitions [Integer] number of partitions we expect
      # @param replication_factor [Integer] number of replicas
      # @param topic_config [Hash] topic config details
      # @see Topics.create
      def create_topic(name, partitions, replication_factor, topic_config = {})
        new.create_topic(name, partitions, replication_factor, topic_config)
      end

      # @param name [String] topic name
      # @see Topics.delete
      def delete_topic(name)
        new.delete_topic(name)
      end

      # @param name [String] topic name
      # @param partitions [Integer] total number of partitions we expect to end up with
      # @see Topics.create_partitions
      def create_partitions(name, partitions)
        new.create_partitions(name, partitions)
      end

      # @param name_or_hash [String, Symbol, Hash] topic name or hash with topics and partitions
      # @param partition [Integer, nil] partition (nil when using hash format)
      # @see Topics.read_watermark_offsets
      def read_watermark_offsets(name_or_hash, partition = nil)
        new.read_watermark_offsets(name_or_hash, partition)
      end

      # @param topic_partition_offsets [Hash{String => Array<Hash>}] topics with partition specs
      # @param isolation_level [Integer, nil] optional isolation level constant
      # @see Topics.read_partition_offsets
      def read_partition_offsets(topic_partition_offsets, isolation_level: nil)
        new.read_partition_offsets(topic_partition_offsets, isolation_level: isolation_level)
      end

      # @param topic_name [String] name of the topic we're interested in
      # @see Topics.info
      def topic_info(topic_name)
        new.topic_info(topic_name)
      end

      # @param group_id [String] id of the group for which we want to move the
      #   existing offset
      # @param topics_with_partitions_and_offsets [Hash] Hash with list of topics and settings
      # @see ConsumerGroups.seek
      def seek_consumer_group(group_id, topics_with_partitions_and_offsets)
        new.seek_consumer_group(group_id, topics_with_partitions_and_offsets)
      end

      # Takes consumer group and its topics and copies all the offsets to a new named group
      #
      # @param previous_name [String] old consumer group name
      # @param new_name [String] new consumer group name
      # @param topics [Array<String>] topics for which we want to migrate offsets during rename
      # @return [Boolean] true if anything was migrated, otherwise false
      # @see ConsumerGroups.copy
      def copy_consumer_group(previous_name, new_name, topics)
        new.copy_consumer_group(previous_name, new_name, topics)
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
        new.rename_consumer_group(
          previous_name,
          new_name,
          topics,
          delete_previous: delete_previous
        )
      end

      # Removes given group (if exists)
      #
      # @param group_id [String] group name
      # @see ConsumerGroups.delete
      def delete_consumer_group(group_id)
        new.delete_consumer_group(group_id)
      end

      # Triggers a rebalance for the specified group
      #
      # @param group_id [String] group id to trigger rebalance for
      # @see ConsumerGroups.trigger_rebalance
      # @note This API should be used only for development.
      def trigger_rebalance(group_id)
        new.trigger_rebalance(group_id)
      end

      # Reads lags and offsets for given topics in the context of groups defined in the routing
      # @param groups_with_topics [Hash{String => Array<String>}] hash with group
      #   names with array of topics to query per group inside
      # @param active_topics_only [Boolean] if set to false, when we use routing topics, will
      #   select also topics that are marked as inactive in routing
      # @return [Hash{String => Hash{Integer => Hash{Integer => Object}}}] hash where the top
      #   level keys are the groups and values are hashes with topics and inside
      #   partitions with lags and offsets
      # @see ConsumerGroups.read_lags_with_offsets
      def read_lags_with_offsets(groups_with_topics = {}, active_topics_only: true)
        new.read_lags_with_offsets(
          groups_with_topics,
          active_topics_only: active_topics_only
        )
      end

      # Plans a replication factor increase for a topic that can be used with Kafka's
      # reassignment tools. Since librdkafka does not support increasing replication factor
      # directly, this method generates the necessary JSON and commands for manual execution.
      #
      # @param topic [String] name of the topic to plan replication for
      # @param replication_factor [Integer] target replication factor (must be higher than current)
      # @param brokers [Hash{Integer => Array<Integer>}] optional manual broker assignments
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
        new.plan_topic_replication(
          topic: topic,
          replication_factor: replication_factor,
          brokers: brokers
        )
      end

      # @return [Rdkafka::Metadata] cluster metadata info
      def cluster_info
        new.cluster_info
      end

      # Creates consumer instance and yields it. After usage it closes the consumer instance
      # This API can be used in other pieces of code and allows for low-level consumer usage
      #
      # @param settings [Hash] extra settings to customize consumer
      #
      # @note We always ship and yield a proxied consumer because admin API performance is not
      #   that relevant. That is, there are no high frequency calls that would have to be delegated
      def with_consumer(settings = {}, &)
        new.with_consumer(settings, &)
      end

      # Creates admin instance and yields it. After usage it closes the admin instance
      def with_admin(&)
        new.with_admin(&)
      end
    end

    # Instance methods - these use the custom kafka configuration

    # @param name [String, Symbol] topic name
    # @param partition [Integer] partition
    # @param count [Integer] how many messages we want to get at most
    # @param start_offset [Integer, Time] offset from which we should start
    # @param settings [Hash] kafka extra settings (optional)
    # @see Topics#read
    def read_topic(name, partition, count, start_offset = -1, settings = {})
      topics_admin.read(name, partition, count, start_offset, settings)
    end

    # @param name [String] topic name
    # @param partitions [Integer] number of partitions for this topic
    # @param replication_factor [Integer] number of replicas
    # @param topic_config [Hash] topic config details
    # @see Topics#create
    def create_topic(name, partitions, replication_factor, topic_config = {})
      topics_admin.create(name, partitions, replication_factor, topic_config)
    end

    # @param name [String] topic name
    # @see Topics#delete
    def delete_topic(name)
      topics_admin.delete(name)
    end

    # @param name [String] topic name
    # @param partitions [Integer] total number of partitions we expect to end up with
    # @see Topics#create_partitions
    def create_partitions(name, partitions)
      topics_admin.create_partitions(name, partitions)
    end

    # @param name_or_hash [String, Symbol, Hash] topic name or hash with topics and partitions
    # @param partition [Integer, nil] partition (nil when using hash format)
    # @see Topics#read_watermark_offsets
    def read_watermark_offsets(name_or_hash, partition = nil)
      topics_admin.read_watermark_offsets(name_or_hash, partition)
    end

    # @param topic_partition_offsets [Hash{String => Array<Hash>}] topics with partition specs
    # @param isolation_level [Integer, nil] optional isolation level constant
    # @see Topics#read_partition_offsets
    def read_partition_offsets(topic_partition_offsets, isolation_level: nil)
      topics_admin.read_partition_offsets(topic_partition_offsets, isolation_level: isolation_level)
    end

    # @param topic_name [String] name of the topic we're interested in
    # @see Topics#info
    def topic_info(topic_name)
      topics_admin.info(topic_name)
    end

    # @param group_id [String] group for which we want to move offsets
    # @param topics_with_partitions_and_offsets [Hash] hash with topics and settings
    # @see ConsumerGroups#seek
    def seek_consumer_group(group_id, topics_with_partitions_and_offsets)
      consumer_groups_admin.seek(
        group_id,
        topics_with_partitions_and_offsets
      )
    end

    # @param previous_name [String] old consumer group name
    # @param new_name [String] new consumer group name
    # @param topics [Array<String>] topics for which we want to copy offsets
    # @see ConsumerGroups#copy
    def copy_consumer_group(previous_name, new_name, topics)
      consumer_groups_admin.copy(previous_name, new_name, topics)
    end

    # @param previous_name [String] old consumer group name
    # @param new_name [String] new consumer group name
    # @param topics [Array<String>] topics for which we want to migrate offsets
    # @param delete_previous [Boolean] should we delete previous consumer group after rename
    # @see ConsumerGroups#rename
    def rename_consumer_group(previous_name, new_name, topics, delete_previous: true)
      consumer_groups_admin.rename(
        previous_name,
        new_name,
        topics,
        delete_previous: delete_previous
      )
    end

    # @param group_id [String] group name
    # @see ConsumerGroups#delete
    def delete_consumer_group(group_id)
      consumer_groups_admin.delete(group_id)
    end

    # @param group_id [String] group id to trigger rebalance for
    # @see ConsumerGroups#trigger_rebalance
    def trigger_rebalance(group_id)
      consumer_groups_admin.trigger_rebalance(group_id)
    end

    # @param groups_with_topics [Hash{String => Array<String>}] hash with group
    #   names with array of topics
    # @param active_topics_only [Boolean] if set to false, will select also inactive topics
    # @see ConsumerGroups#read_lags_with_offsets
    def read_lags_with_offsets(groups_with_topics = {}, active_topics_only: true)
      consumer_groups_admin.read_lags_with_offsets(
        groups_with_topics,
        active_topics_only: active_topics_only
      )
    end

    # @param topic [String] topic name to plan replication for
    # @param replication_factor [Integer] target replication factor
    # @param brokers [Hash, nil] optional manual broker assignments per partition
    # @see Replication#plan
    def plan_topic_replication(topic:, replication_factor:, brokers: nil)
      Replication.new(kafka: @custom_kafka).plan(
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
    #
    # @note When an external client is present, it is yielded directly and its lifecycle is not
    #   managed here in any way: no oauth binding, no start and no closing. `settings` are
    #   ignored as the external instance is already configured and operations run within its
    #   identity, including its `group.id`. External rdkafka admin instances are not used here
    #   as they are not capable of consumer operations - they are used by `#with_admin` instead.
    def with_consumer(settings = {})
      return yield(Karafka::Connection::Proxy.new(@external_client)) if external_consumer?

      bind_id = SecureRandom.uuid
      consumer = nil

      begin
        consumer = config(:consumer, settings).consumer(native_kafka_auto_start: false)
        bind_oauth(bind_id, consumer)

        consumer.start
        proxy = Karafka::Connection::Proxy.new(consumer)
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
    end

    # Creates admin instance and yields it. After usage it closes the admin instance
    #
    # @note When the external client is an rdkafka admin instance, it is yielded directly and
    #   its lifecycle is not managed here in any way, same as with `#with_consumer`. External
    #   clients of other types (consumers, producers) are not capable of admin operations, thus
    #   a dedicated admin instance is created for them as usual.
    def with_admin
      return yield(Karafka::Connection::Proxy.new(@external_client)) if external_admin?

      bind_id = SecureRandom.uuid
      admin = nil

      begin
        admin = config(:producer, {}).admin(
          native_kafka_auto_start: false,
          native_kafka_poll_timeout_ms: self.class.poll_timeout
        )

        bind_oauth(bind_id, admin)

        admin.start
        proxy = Karafka::Connection::Proxy.new(admin)
        yield(proxy)
      ensure
        admin&.close

        unbind_oauth(bind_id)
      end
    end

    private

    # @return [Boolean] true when the external client is an rdkafka admin instance (raw or
    #   proxied) capable of admin operations
    def external_admin?
      return false unless @external_client

      client = @external_client
      client = client.wrapped if client.is_a?(Karafka::Connection::Proxy)

      client.is_a?(Rdkafka::Admin)
    end

    # @return [Boolean] true when the external client should be used for consumer operations.
    #   Any external client that is not an rdkafka admin instance is assumed to be consumer
    #   capable - it is the caller responsibility to provide a client that can handle the
    #   invoked operations
    def external_consumer?
      !@external_client.nil? && !external_admin?
    end

    # @return [Topics] topics admin operating within this instance context (custom kafka and
    #   external client carried over)
    def topics_admin
      Topics.new(kafka: @custom_kafka, external_client: @external_client)
    end

    # @return [ConsumerGroups] consumer groups admin operating within this instance context
    #   (custom kafka and external client carried over)
    def consumer_groups_admin
      ConsumerGroups.new(kafka: @custom_kafka, external_client: @external_client)
    end

    # @return [Integer] max wait time in ms
    def max_wait_time_ms
      self.class.max_wait_time
    end

    # Adds a new callback for given rdkafka instance for oauth token refresh (if needed)
    #
    # @param id [String, Symbol] unique (for the lifetime of instance) id that we use for
    #   callback referencing
    # @param instance [Rdkafka::Consumer, Rdkafka::Admin] rdkafka instance to be used to set
    #   appropriate oauth token when needed
    def bind_oauth(id, instance)
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.add(
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
      Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(id)
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
      start_time = self.class.monotonic_now
      # Convert milliseconds to seconds for sleep
      sleep_time = self.class.retry_backoff / 1000.0

      loop do
        handler.call

        sleep(sleep_time)

        return if breaker.call
      rescue Rdkafka::AbstractHandle::WaitTimeoutError
        return if breaker.call

        next if self.class.monotonic_now - start_time < self.class.max_retries_duration

        raise(Errors::ResultNotVisibleError)
      end
    end

    # @param type [Symbol] type of config we want
    # @param settings [Hash] extra settings for config (if needed)
    # @return [::Rdkafka::Config] rdkafka config
    def config(type, settings)
      kafka_config = self.class.app_kafka.dup
      kafka_config.merge!(self.class.admin_kafka)
      kafka_config[:"group.id"] = self.class.group_id
      # We merge after setting the group id so it can be altered if needed
      # In general in admin we only should alter it when we need to impersonate a given
      # consumer group or do something similar
      kafka_config.merge!(settings)
      # Custom kafka config is merged last so it can override all other settings
      # This enables multi-cluster support where custom_kafka specifies a different cluster
      kafka_config.merge!(@custom_kafka)

      mapped_config = Karafka::Setup::AttributesMap.public_send(type, kafka_config)

      Rdkafka::Config.new(mapped_config)
    end
  end
end

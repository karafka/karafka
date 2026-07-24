# frozen_string_literal: true

module Karafka
  class Admin
    # Topic administration operations
    # Provides methods to manage Kafka topics including creation, deletion, reading, and
    # introspection
    class Topics < Admin
      class << self
        # @param name [String, Symbol] topic name
        # @param partition [Integer] partition
        # @param count [Integer] how many messages we want to get at most
        # @param start_offset [Integer, Time] offset from which we should start
        # @param settings [Hash] kafka extra settings (optional)
        # @see #read
        def read(name, partition, count, start_offset = -1, settings = {})
          new.read(name, partition, count, start_offset, settings)
        end

        # @param name [String] topic name
        # @param partitions [Integer] number of partitions for this topic
        # @param replication_factor [Integer] number of replicas
        # @param topic_config [Hash] topic config details as described in the
        #   `base topic configuration`))
        # @see #create
        def create(name, partitions, replication_factor, topic_config = {})
          new.create(name, partitions, replication_factor, topic_config)
        end

        # @param name [String] topic name
        # @see #delete
        def delete(name)
          new.delete(name)
        end

        # @param name [String] topic name
        # @param partitions [Integer] total number of partitions we expect to end up with
        # @see #create_partitions
        def create_partitions(name, partitions)
          new.create_partitions(name, partitions)
        end

        # @param name_or_hash [String, Symbol, Hash] topic name or hash with topics and partitions
        # @param partition [Integer, nil] partition (nil when using hash format)
        # @see #read_watermark_offsets
        def read_watermark_offsets(name_or_hash, partition = nil)
          new.read_watermark_offsets(name_or_hash, partition)
        end

        # @param topic_name [String] name of the topic we're interested in
        # @see #info
        def info(topic_name)
          new.info(topic_name)
        end

        # @param topic_partition_offsets [Hash{String => Array<Hash>}] topics with partition specs
        # @param isolation_level [Integer, nil] optional isolation level constant
        # @see #read_partition_offsets
        def read_partition_offsets(topic_partition_offsets, isolation_level: nil)
          new.read_partition_offsets(topic_partition_offsets, isolation_level: isolation_level)
        end
      end

      # Allows us to read messages from the topic
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer, Time] offset from which we should start. If -1 is provided
      #   (default) we will start from the latest offset. If time is provided, the appropriate
      #   offset will be resolved. A time beyond the last message yields no messages. If
      #   negative beyond -1 is provided, we move backwards more.
      # @param settings [Hash] kafka extra settings (optional)
      #
      # @return [Array<Karafka::Messages::Message>] array with messages
      def read(name, partition, count, start_offset = -1, settings = {})
        messages = []
        tpl = Rdkafka::Consumer::TopicPartitionList.new
        low_offset, high_offset = nil
        time_based = start_offset.is_a?(Time)

        with_consumer(settings) do |consumer|
          # Convert the time offset (if needed)
          start_offset = resolve_offset(consumer, name.to_s, partition, start_offset)

          low_offset, high_offset = consumer.query_watermark_offsets(name, partition)

          if start_offset.negative?
            start_offset = if time_based
              # A negative result of time resolution means there is no message at or after the
              # requested time. It must not fall into the numeric relative form below (which
              # would return the newest messages, all older than requested): starting at the
              # high watermark yields the correct empty result
              high_offset
            else
              # Select offset dynamically if -1 or less and move backwards with the negative
              # offset, allowing to start from N messages back from high-watermark
              high_offset - count - start_offset.abs + 1
            end
          end

          start_offset = low_offset if start_offset.negative?

          # Build the requested range - since first element is on the start offset we need to
          # subtract one from requested count to end up with expected number of elements
          requested_range = (start_offset..(start_offset + count - 1))
          # Establish theoretical available range. Note, that this does not handle cases related
          # to log retention or compaction
          available_range = (low_offset..(high_offset - 1))
          # Select only offset that we can select. This will remove all the potential offsets
          # that are below the low watermark offset
          possible_range = requested_range.select { |offset| available_range.include?(offset) }

          start_offset = possible_range.first
          count = possible_range.size

          tpl.add_topic_and_partitions_with_offsets(name, partition => start_offset)
          consumer.assign(tpl)

          # We should poll as long as we don't have all the messages that we need or as long as
          # we do not read all the messages from the topic
          loop do
            # If we've got as many messages as we've wanted stop
            break if messages.size >= count

            message = consumer.poll(200)

            next unless message

            # If the message we've got is beyond the requested range, stop
            break unless possible_range.include?(message.offset)

            messages << message
          rescue Rdkafka::RdkafkaError => e
            # End of partition
            break if e.code == :partition_eof

            raise e
          end
        end

        # Use topic from routes if we can match it or create a dummy one
        # Dummy one is used in case we cannot match the topic with routes. This can happen
        # when admin API is used to read topics that are not part of the routing
        topic = Karafka::Routing::Router.find_or_initialize_by_name(name)

        messages.map! do |message|
          Messages::Builders::Message.call(
            message,
            topic,
            Time.now
          )
        end
      end

      # Creates Kafka topic with given settings
      #
      # @param name [String] topic name
      # @param partitions [Integer] number of partitions we expect
      # @param replication_factor [Integer] number of replicas
      # @param topic_config [Hash] topic config details as described here:
      #   https://kafka.apache.org/documentation/#topicconfigs
      #
      # @return [void]
      def create(name, partitions, replication_factor, topic_config = {})
        with_admin do |admin|
          handler = admin.create_topic(name, partitions, replication_factor, topic_config)

          with_re_wait(
            -> { handler.wait(max_wait_timeout_ms: max_wait_time_ms) },
            -> { names.include?(name) }
          )
        end
      end

      # Deleted a given topic
      #
      # @param name [String] topic name
      #
      # @return [void]
      def delete(name)
        with_admin do |admin|
          handler = admin.delete_topic(name)

          with_re_wait(
            -> { handler.wait(max_wait_timeout_ms: max_wait_time_ms) },
            -> { !names.include?(name) }
          )
        end
      end

      # Creates more partitions for a given topic
      #
      # @param name [String] topic name
      # @param partitions [Integer] total number of partitions we expect to end up with
      #
      # @return [void]
      def create_partitions(name, partitions)
        with_admin do |admin|
          handler = admin.create_partitions(name, partitions)

          with_re_wait(
            -> { handler.wait(max_wait_timeout_ms: max_wait_time_ms) },
            -> { info(name).fetch(:partition_count) >= partitions }
          )
        end
      end

      # Fetches the watermark offsets for a given topic partition or multiple topics and partitions
      #
      # @param name_or_hash [String, Symbol, Hash] topic name or hash with topics and partitions
      # @param partition [Integer, nil] partition number
      #   (required when first param is topic name)
      #
      # @return [Array<Integer, Integer>, Hash] when querying single partition returns array with
      #   low and high watermark offsets, when querying multiple returns nested hash
      #
      # @example Query single partition
      #   Karafka::Admin::Topics.read_watermark_offsets('events', 0)
      #   # => [0, 100]
      #
      # @example Query specific partitions across multiple topics
      #   Karafka::Admin::Topics.read_watermark_offsets(
      #     { 'events' => [0, 1], 'logs' => [0] }
      #   )
      #   # => {
      #   #   'events' => {
      #   #     0 => [0, 100],
      #   #     1 => [0, 150]
      #   #   },
      #   #   'logs' => {
      #   #     0 => [0, 50]
      #   #   }
      #   # }
      def read_watermark_offsets(name_or_hash, partition = nil)
        # Normalize input to hash format
        topics_with_partitions = partition ? { name_or_hash => [partition] } : name_or_hash

        low_specs = {}
        high_specs = {}

        topics_with_partitions.each do |topic, partitions|
          low_specs[topic] = partitions.map { |p| { partition: p, offset: :earliest } }
          high_specs[topic] = partitions.map { |p| { partition: p, offset: :latest } }
        end

        lows = {}
        highs = {}

        with_admin do |admin|
          admin.list_offsets(low_specs).wait(max_wait_timeout_ms: max_wait_time_ms).offsets.each do |r|
            (lows[r[:topic]] ||= {})[r[:partition]] = r[:offset]
          end
          admin.list_offsets(high_specs).wait(max_wait_timeout_ms: max_wait_time_ms).offsets.each do |r|
            (highs[r[:topic]] ||= {})[r[:partition]] = r[:offset]
          end
        end

        result = Hash.new { |h, k| h[k] = {} }
        topics_with_partitions.each do |topic, partitions|
          partitions.each do |partition_id|
            result[topic][partition_id] = [lows.dig(topic.to_s, partition_id), highs.dig(topic.to_s, partition_id)]
          end
        end

        # Return single array for single partition query, hash for multiple
        partition ? result.dig(name_or_hash, partition) : result
      end

      # Queries partition offsets by specification using the Kafka ListOffsets admin API.
      #
      # This is a lower-level, more flexible alternative to `#read_watermark_offsets`. The key
      # differences are:
      #
      # - Transactional correctness: `read_watermark_offsets` always returns the high-watermark
      #   offset, which includes messages from uncommitted or in-flight transactions. A
      #   `READ_COMMITTED` consumer will never see those messages, so lag calculated from the
      #   high-watermark is overstated on transactionally-produced topics. Passing
      #   `isolation_level: Karafka::Admin::IsolationLevels::READ_COMMITTED` here
      #   returns the Last Stable Offset (LSO) — the highest offset a `READ_COMMITTED` consumer
      #   would actually reach — giving accurate lag figures.
      #
      # - `:max_timestamp` spec: returns the offset of the message with the highest timestamp
      #   in the partition. Not available via watermarks.
      #
      # - Leader epoch: the response includes `leader_epoch`, which can be used to detect
      #   stale metadata or fencing conditions.
      #
      # - Admin API: operates through the admin client rather than a consumer connection.
      #
      # For non-transactional topics, `:latest` here and `read_watermark_offsets` high-watermark
      # return the same value.
      #
      # @param topic_partition_offsets [Hash{String => Array<Hash>}] hash with topic names as keys
      #   and arrays of partition specs as values. Each spec must have:
      #   - `:partition` [Integer] the partition number
      #   - `:offset` [Symbol, Integer] `:earliest`, `:latest`, `:max_timestamp`, or an Integer
      #     timestamp in milliseconds (returns the first offset at or after that timestamp)
      #   Each partition may appear at most once per call.
      # @param isolation_level [Integer, nil] optional isolation level constant. Pass
      #   `Karafka::Admin::IsolationLevels::READ_COMMITTED` to get the LSO instead of the
      #   high-watermark for `:latest` queries on transactionally-produced topics.
      #
      # @return [Array<Hash>] array of result hashes, each containing:
      #   - `:topic` [String]
      #   - `:partition` [Integer]
      #   - `:offset` [Integer]
      #   - `:timestamp` [Integer] (-1 when not applicable)
      #   - `:leader_epoch` [Integer, nil]
      #
      # @raise [Rdkafka::RdkafkaError] on per-partition errors or connection issues
      #
      # @note The specs must be passed as an explicit hash (in curly braces). Ruby parses a
      #   brace-less trailing hash as keyword arguments, and since this method takes an
      #   `isolation_level:` keyword, such a call raises an `ArgumentError` about a missing
      #   positional argument.
      #
      # @example Query earliest offset for partition 0 and latest for partition 1
      #   Karafka::Admin::Topics.read_partition_offsets(
      #     {
      #       'events' => [
      #         { partition: 0, offset: :earliest },
      #         { partition: 1, offset: :latest }
      #       ]
      #     }
      #   )
      #   # => [
      #   #   { topic: 'events', partition: 0, offset: 0, timestamp: -1, leader_epoch: nil },
      #   #   { topic: 'events', partition: 1, offset: 100, timestamp: -1, leader_epoch: nil }
      #   # ]
      #
      # @example Get LSO (Last Stable Offset) for accurate lag on transactional topics
      #   Karafka::Admin::Topics.read_partition_offsets(
      #     { 'events' => [{ partition: 0, offset: :latest }] },
      #     isolation_level: Karafka::Admin::IsolationLevels::READ_COMMITTED
      #   )
      #
      # @example Find offset at a specific point in time
      #   Karafka::Admin::Topics.read_partition_offsets(
      #     { 'events' => [{ partition: 0, offset: 1_700_000_000_000 }] }
      #   )
      def read_partition_offsets(topic_partition_offsets, isolation_level: nil)
        with_admin do |admin|
          handle = admin.list_offsets(topic_partition_offsets, isolation_level: isolation_level)
          handle.wait(max_wait_timeout_ms: max_wait_time_ms).offsets
        end
      end

      # Returns basic topic metadata
      #
      # @param topic_name [String] name of the topic we're interested in
      # @return [Hash] topic metadata info hash
      # @raise [Rdkafka::RdkafkaError] `unknown_topic_or_part` if requested topic is not found
      #
      # @note This query is much more efficient than doing a full `#cluster_info` + topic lookup
      #   because it does not have to query for all the topics data but just the topic we're
      #   interested in
      def info(topic_name)
        with_admin do |admin|
          admin
            .metadata(topic_name)
            .topics
            .find { |topic| topic[:topic_name] == topic_name }
        end
      end

      private

      # @return [Array<String>] topics names
      def names
        cluster_info.topics.map { |topic| topic.fetch(:topic_name) }
      end

      # Resolves the offset if offset is in a time format. Otherwise returns the offset without
      # resolving.
      # @param consumer [::Rdkafka::Consumer]
      # @param name [String, Symbol] expected topic name
      # @param partition [Integer]
      # @param offset [Integer, Time]
      # @return [Integer] expected offset
      def resolve_offset(consumer, name, partition, offset)
        if offset.is_a?(Time)
          tpl = Rdkafka::Consumer::TopicPartitionList.new
          tpl.add_topic_and_partitions_with_offsets(
            name, partition => offset
          )

          real_offsets = consumer.offsets_for_times(tpl)
          detected_offset = real_offsets
            .to_h
            .fetch(name)
            .find { |p_data| p_data.partition == partition }

          detected_offset&.offset || raise(Errors::InvalidTimeBasedOffsetError)
        else
          offset
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Simple admin actions that we can perform via Karafka on our Kafka cluster
  #
  # @note It always initializes a new admin instance as we want to ensure it is always closed
  #   Since admin actions are not performed that often, that should be ok.
  #
  # @note It always uses the primary defined cluster and does not support multi-cluster work.
  #   If you need this, just replace the cluster info for the time you use this
  module Admin
    # We wait only for this amount of time before raising error as we intercept this error and
    # retry after checking that the operation was finished or failed using external factor.
    MAX_WAIT_TIMEOUT = 1

    # Max time for a TPL request. We increase it to compensate for remote clusters latency
    TPL_REQUEST_TIMEOUT = 2_000

    # How many times should be try. 1 x 60 => 60 seconds wait in total
    MAX_ATTEMPTS = 60

    # Defaults for config
    CONFIG_DEFAULTS = {
      'group.id': 'karafka_admin',
      # We want to know when there is no more data not to end up with an endless loop
      'enable.partition.eof': true,
      'statistics.interval.ms': 0,
      # Fetch at most 5 MBs when using admin
      'fetch.message.max.bytes': 5 * 1_048_576,
      # Do not commit offset automatically, this prevents offset tracking for operations involving
      # a consumer instance
      'enable.auto.commit': false
    }.freeze

    private_constant :CONFIG_DEFAULTS, :MAX_WAIT_TIMEOUT, :TPL_REQUEST_TIMEOUT,
                     :MAX_ATTEMPTS

    class << self
      # Allows us to read messages from the topic
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer, Time] offset from which we should start. If -1 is provided
      #   (default) we will start from the latest offset. If time is provided, the appropriate
      #   offset will be resolved.
      # @param settings [Hash] kafka extra settings (optional)
      #
      # @return [Array<Karafka::Messages::Message>] array with messages
      def read_topic(name, partition, count, start_offset = -1, settings = {})
        messages = []
        tpl = Rdkafka::Consumer::TopicPartitionList.new
        low_offset, high_offset = nil

        with_consumer(settings) do |consumer|
          # Convert the time offset (if needed)
          start_offset = resolve_offset(consumer, name.to_s, partition, start_offset)

          low_offset, high_offset = consumer.query_watermark_offsets(name, partition)

          # Select offset dynamically if -1 or less
          start_offset = high_offset - count if start_offset.negative?

          # Build the requested range - since first element is on the start offset we need to
          # subtract one from requested count to end up with expected number of elements
          requested_range = (start_offset..start_offset + (count - 1))
          # Establish theoretical available range. Note, that this does not handle cases related to
          # log retention or compaction
          available_range = (low_offset..high_offset)
          # Select only offset that we can select. This will remove all the potential offsets that
          # are below the low watermark offset
          possible_range = requested_range.select { |offset| available_range.include?(offset) }

          start_offset = possible_range.first
          count = possible_range.count

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
        topic = ::Karafka::Routing::Router.find_or_initialize_by_name(name)

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
      def create_topic(name, partitions, replication_factor, topic_config = {})
        with_admin do |admin|
          handler = admin.create_topic(name, partitions, replication_factor, topic_config)

          with_re_wait(
            -> { handler.wait(max_wait_timeout: MAX_WAIT_TIMEOUT) },
            -> { topics_names.include?(name) }
          )
        end
      end

      # Deleted a given topic
      #
      # @param name [String] topic name
      def delete_topic(name)
        with_admin do |admin|
          handler = admin.delete_topic(name)

          with_re_wait(
            -> { handler.wait(max_wait_timeout: MAX_WAIT_TIMEOUT) },
            -> { !topics_names.include?(name) }
          )
        end
      end

      # Creates more partitions for a given topic
      #
      # @param name [String] topic name
      # @param partitions [Integer] total number of partitions we expect to end up with
      def create_partitions(name, partitions)
        with_admin do |admin|
          handler = admin.create_partitions(name, partitions)

          with_re_wait(
            -> { handler.wait(max_wait_timeout: MAX_WAIT_TIMEOUT) },
            -> { topic(name).fetch(:partition_count) >= partitions }
          )
        end
      end

      # Fetches the watermark offsets for a given topic partition
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @return [Array<Integer, Integer>] low watermark offset and high watermark offset
      def read_watermark_offsets(name, partition)
        with_consumer do |consumer|
          consumer.query_watermark_offsets(name, partition)
        end
      end

      # @return [Rdkafka::Metadata] cluster metadata info
      def cluster_info
        with_admin do |admin|
          admin.instance_variable_get('@native_kafka').with_inner do |inner|
            Rdkafka::Metadata.new(inner)
          end
        end
      end

      # Creates consumer instance and yields it. After usage it closes the consumer instance
      # This API can be used in other pieces of code and allows for low-level consumer usage
      #
      # @param settings [Hash] extra settings to customize consumer
      def with_consumer(settings = {})
        consumer = config(:consumer, settings).consumer
        yield(consumer)
      ensure
        consumer&.close
      end

      private

      # @return [Array<String>] topics names
      def topics_names
        cluster_info.topics.map { |topic| topic.fetch(:topic_name) }
      end

      # Finds details about given topic
      # @param name [String] topic name
      # @return [Hash] topic details
      def topic(name)
        cluster_info.topics.find { |topic| topic[:topic_name] == name }
      end

      # Creates admin instance and yields it. After usage it closes the admin instance
      def with_admin
        admin = config(:producer, {}).admin
        yield(admin)
      ensure
        admin&.close
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
        attempt ||= 0
        attempt += 1

        handler.call
      rescue Rdkafka::AbstractHandle::WaitTimeoutError
        return if breaker.call

        retry if attempt <= MAX_ATTEMPTS

        raise
      end

      # @param type [Symbol] type of config we want
      # @param settings [Hash] extra settings for config (if needed)
      # @return [::Rdkafka::Config] rdkafka config
      def config(type, settings)
        config_hash = Karafka::Setup::AttributesMap.public_send(
          type,
          Karafka::App.config.kafka.dup.merge(CONFIG_DEFAULTS).merge!(settings)
        )

        ::Rdkafka::Config.new(config_hash)
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
          tpl = ::Rdkafka::Consumer::TopicPartitionList.new
          tpl.add_topic_and_partitions_with_offsets(
            name, partition => offset
          )

          real_offsets = consumer.offsets_for_times(tpl, TPL_REQUEST_TIMEOUT)
          detected_offset = real_offsets.to_h.dig(name, partition)

          detected_offset&.offset || raise(Errors::InvalidTimeBasedOffsetError)
        else
          offset
        end
      end
    end
  end
end

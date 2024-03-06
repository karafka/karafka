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
  module Admin
    class << self
      # Allows us to read messages from the topic
      #
      # @param name [String, Symbol] topic name
      # @param partition [Integer] partition
      # @param count [Integer] how many messages we want to get at most
      # @param start_offset [Integer, Time] offset from which we should start. If -1 is provided
      #   (default) we will start from the latest offset. If time is provided, the appropriate
      #   offset will be resolved. If negative beyond -1 is provided, we move backwards more.
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

          # Select offset dynamically if -1 or less and move backwards with the negative
          # offset, allowing to start from N messages back from high-watermark
          start_offset = high_offset - count - start_offset.abs + 1 if start_offset.negative?
          start_offset = low_offset if start_offset.negative?

          # Build the requested range - since first element is on the start offset we need to
          # subtract one from requested count to end up with expected number of elements
          requested_range = (start_offset..start_offset + (count - 1))
          # Establish theoretical available range. Note, that this does not handle cases related to
          # log retention or compaction
          available_range = (low_offset..(high_offset - 1))
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
            -> { handler.wait(max_wait_timeout: app_config.admin.max_wait_time) },
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
            -> { handler.wait(max_wait_timeout: app_config.admin.max_wait_time) },
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
            -> { handler.wait(max_wait_timeout: app_config.admin.max_wait_time) },
            -> { topic(name).fetch(:partition_count) >= partitions }
          )
        end
      end

      # Moves the offset on a given consumer group and provided topic to the requested location
      #
      # @param consumer_group_id [String] id of the consumer group for which we want to move the
      #   existing offset
      # @param topics_with_partitions_and_offsets [Hash] Hash with list of topics and settings to
      #   where to move given consumer. It allows us to move particular partitions or whole topics
      #   if we want to reset all partitions to for example a point in time.
      #
      # @note This method should **not** be executed on a running consumer group as it creates a
      #   "fake" consumer and uses it to move offsets.
      #
      # @example Move a single topic partition nr 1 offset to 100
      #   Karafka::Admin.seek_consumer_group('group-id', { 'topic' => { 1 => 100 } })
      #
      # @example Move offsets on all partitions of a topic to 100
      #   Karafka::Admin.seek_consumer_group('group-id', { 'topic' => 100 })
      #
      # @example Move offset to 5 seconds ago on partition 2
      #   Karafka::Admin.seek_consumer_group('group-id', { 'topic' => { 2 => 5.seconds.ago } })
      def seek_consumer_group(consumer_group_id, topics_with_partitions_and_offsets)
        tpl_base = {}

        # Normalize the data so we always have all partitions and topics in the same format
        # That is in a format where we have topics and all partitions with their per partition
        # assigned offsets
        topics_with_partitions_and_offsets.each do |topic, partitions_with_offsets|
          tpl_base[topic] = {}

          if partitions_with_offsets.is_a?(Hash)
            tpl_base[topic] = partitions_with_offsets
          else
            topic(topic)[:partition_count].times do |partition|
              tpl_base[topic][partition] = partitions_with_offsets
            end
          end
        end

        tpl = Rdkafka::Consumer::TopicPartitionList.new
        # In case of time based location, we need to to a pre-resolution, that's why we keep it
        # separately
        time_tpl = Rdkafka::Consumer::TopicPartitionList.new

        # Distribute properly the offset type
        tpl_base.each do |topic, partitions_with_offsets|
          partitions_with_offsets.each do |partition, offset|
            target = offset.is_a?(Time) ? time_tpl : tpl
            target.add_topic_and_partitions_with_offsets(topic, [[partition, offset]])
          end
        end

        settings = { 'group.id': consumer_group_id }

        with_consumer(settings) do |consumer|
          # If we have any time based stuff to resolve, we need to do it prior to commits
          unless time_tpl.empty?
            real_offsets = consumer.offsets_for_times(time_tpl)

            real_offsets.to_h.each do |name, results|
              results.each do |result|
                raise(Errors::InvalidTimeBasedOffsetError) unless result

                partition = result.partition

                # Negative offset means we're beyond last message and we need to query for the
                # high watermark offset to get the most recent offset and move there
                if result.offset.negative?
                  _, offset = consumer.query_watermark_offsets(name, result.partition)
                else
                  # If we get an offset, it means there existed a message close to this time
                  # location
                  offset = result.offset
                end

                # Since now we have proper offsets, we can add this to the final tpl for commit
                tpl.add_topic_and_partitions_with_offsets(name, [[partition, offset]])
              end
            end
          end

          consumer.commit(tpl, false)
        end
      end

      # Removes given consumer group (if exists)
      #
      # @param consumer_group_id [String] consumer group name
      #
      # @note This method should not be used on a running consumer group as it will not yield any
      #   results.
      def delete_consumer_group(consumer_group_id)
        with_admin do |admin|
          handler = admin.delete_group(consumer_group_id)
          handler.wait(max_wait_timeout: app_config.admin.max_wait_time)
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

      # Reads lags for given topics in the context of consumer groups defined in the routing
      # @param consumer_groups_with_topics [Hash<String, Array<String>>] hash with consumer groups
      #   names with array of topics to query per consumer group inside
      # @return [Hash<String, Hash<Integer, Integer>>] hash where the top level keys are the
      #   consumer groups and values are hashes with topics and inside partitions with lags
      #
      # @note For topics that do not exist, topic details will be set to an empty hash
      #
      # @note For topics that exist but were never consumed by a given CG we set `-1` but
      #   on each of the partitions that were not consumed.
      #
      # @note This lag reporting is for committed lags and is "Kafka-centric", meaning that this
      #   represents lags from Kafka perspective and not the consumer. They may differ.
      def read_lags(consumer_groups_with_topics = {})
        # We first fetch all the topics with partitions count that exist in the cluster so we
        # do not query for topics that do not exist and so we can get partitions count for all
        # the topics we may need. The non-existent and not consumed will be filled at the end
        existing_topics = cluster_info.topics.map do |topic|
          [topic[:topic_name], topic[:partition_count]]
        end.to_h.freeze

        # If no expected CGs, we use all from routing that have active topics
        if consumer_groups_with_topics.empty?
          consumer_groups_with_topics = Karafka::App.routes.map do |cg|
            cg_topics = cg.topics.select(&:active?).map(&:name)

            [cg.id, cg_topics]
          end.to_h
        end

        # We make a copy because we will remove once with non-existing topics
        # We keep original requested consumer groups with topics for later backfilling
        cgs_with_topics = consumer_groups_with_topics.dup
        cgs_with_topics.transform_values!(&:dup)

        # We can query only topics that do exist, this is why we are cleaning those that do not
        # exist
        cgs_with_topics.each_value do |requested_topics|
          requested_topics.delete_if { |topic| !existing_topics.include?(topic) }
        end

        groups_lags = Hash.new { |h, k| h[k] = {} }

        cgs_with_topics.each do |cg, topics|
          # Do not add to tpl topics that do not exist
          next if topics.empty?

          tpl = Rdkafka::Consumer::TopicPartitionList.new

          with_consumer('group.id': cg) do |consumer|
            topics.each { |topic| tpl.add_topic(topic, existing_topics[topic]) }

            consumer.lag(consumer.committed(tpl)).each do |topic, partitions_lags|
              groups_lags[cg][topic] = partitions_lags
            end
          end
        end

        consumer_groups_with_topics.each do |cg, topics|
          groups_lags[cg]

          topics.each do |topic|
            groups_lags[cg][topic] ||= {}

            next unless existing_topics.key?(topic)

            # We backfill because there is a case where our consumer group would consume for
            # example only one partition out of 20, rest needs to get -1
            existing_topics[topic].times do |partition_id|
              groups_lags[cg][topic][partition_id] ||= -1
            end
          end
        end

        groups_lags
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
        consumer = config(:consumer, settings).consumer
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
      end

      # Creates admin instance and yields it. After usage it closes the admin instance
      def with_admin
        admin = config(:producer, {}).admin
        yield(admin)
      ensure
        admin&.close
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

        # If breaker does not operate, it means that the requested change was applied but is still
        # not visible and we need to wait
        raise(Errors::ResultNotVisibleError) unless breaker.call
      rescue Rdkafka::AbstractHandle::WaitTimeoutError, Errors::ResultNotVisibleError
        return if breaker.call

        retry if attempt <= app_config.admin.max_attempts

        raise
      end

      # @param type [Symbol] type of config we want
      # @param settings [Hash] extra settings for config (if needed)
      # @return [::Rdkafka::Config] rdkafka config
      def config(type, settings)
        app_config
          .kafka
          .then(&:dup)
          .merge(app_config.admin.kafka)
          .tap { |config| config[:'group.id'] = app_config.admin.group_id }
          # We merge after setting the group id so it can be altered if needed
          # In general in admin we only should alter it when we need to impersonate a given
          # consumer group or do something similar
          .merge!(settings)
          .then { |config| Karafka::Setup::AttributesMap.public_send(type, config) }
          .then { |config| ::Rdkafka::Config.new(config) }
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

      # @return [Karafka::Core::Configurable::Node] root node config
      def app_config
        ::Karafka::App.config
      end
    end
  end
end

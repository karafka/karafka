# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Topic iterator allows you to iterate over topic/partition data and perform lookups for
    # information that you need.
    #
    # It supports early stops on finding the requested data and allows for seeking till
    # the end. It also allows for signaling, when a given message should be last out of certain
    # partition, but we still want to continue iterating in other messages.
    #
    # It does **not** create a consumer group and does not have any offset management.
    class Iterator
      # Local partition reference for librdkafka
      Partition = Struct.new(:partition, :offset)

      private_constant :Partition

      # A simple API allowing to iterate over topic/partition data, without having to subscribe
      # and deal with rebalances. This API allows for multi-partition streaming and is optimized
      # for data lookups. It allows for explicit stopping iteration over any partition during
      # the iteration process, allowing for optimized lookups.
      #
      # @param topics [Array<String>, Hash] list of strings if we want to subscribe to multiple
      #   topics and all of their partitions or a hash where keys are the topics and values are
      #   hashes with partitions and their initial offsets.
      # @param settings [Hash] extra settings for the consumer. Please keep in mind, that if
      #   overwritten, you may want to include `auto.offset.reset` to match your case.
      # @param yield_nil [Boolean] should we yield also `nil` values when poll returns nothing.
      #   Useful in particular for long-living iterators.
      #
      # @note It is worth keeping in mind, that this API also needs to operate within
      #   `max.poll.interval.ms` limitations on each iteration
      #
      # @note In case of a never-ending iterator, you need to set `enable.partition.eof` to `false`
      #   so we don't stop polling data even when reaching the end (end on a given moment)
      def initialize(
        topics,
        settings: { 'auto.offset.reset': 'beginning' },
        yield_nil: false
      )
        @topics_with_partitions = expand_topics_with_partitions(topics)

        @routing_topics = @topics_with_partitions.map do |name, _|
          [name, ::Karafka::Routing::Router.find_or_initialize_by_name(name)]
        end.to_h

        @total_partitions = @topics_with_partitions.map(&:last).sum(&:count)

        @stopped_partitions = 0

        @settings = settings
        @yield_nil = yield_nil
      end

      # Iterates over requested topic partitions and yields the results with the iterator itself
      # Iterator instance is yielded because one can run `stop_partition` to stop iterating over
      # part of data. It is useful for scenarios where we are looking for some information in all
      # the partitions but once we found it, given partition data is no longer needed and would
      # only eat up resources.
      def each
        Admin.with_consumer(@settings) do |consumer|
          tpl = tpl_with_expanded_offsets(consumer)
          consumer.assign(tpl)

          # We need this for self-referenced APIs like pausing
          @current_consumer = consumer

          # Stream data until we reach the end of all the partitions or until the end user
          # indicates that they are done
          until done?
            message = poll(200)

            # Skip nils if not explicitely required
            next if message.nil? && !@yield_nil

            if message
              @current_message = build_message(message)

              yield(@current_message, self)
            else
              yield(nil, self)
            end
          end

          @current_message = nil
          @current_consumer = nil
        end

        # Reset so we can use the same iterator again if needed
        @stopped_partitions = 0
      end

      # Stops the partition we're currently yielded into
      def stop_current_partition
        stop_partition(
          @current_message.topic,
          @current_message.partition
        )
      end

      # Stops processing of a given partition
      # We expect the partition to be provided because of a scenario, where there is a
      # multi-partition iteration and we want to stop a different partition that the one that
      # is currently yielded.
      #
      # We pause it forever and no longer work with it.
      #
      # @param name [String] topic name of which partition we want to stop
      # @param partition [Integer] partition we want to stop processing
      def stop_partition(name, partition)
        @stopped_partitions += 1

        @current_consumer.pause(
          Rdkafka::Consumer::TopicPartitionList.new(
            name => [Partition.new(partition, 0)]
          )
        )
      end

      private

      # Expands topics to which we want to subscribe with partitions information in case this
      # info is not provided. For our convenience we want to support 5 formats of defining
      # the subscribed topics:
      #
      # - 'topic1' - just a string with one topic name
      # - ['topic1', 'topic2'] - just the names
      # - { 'topic1' => -100 } - names with negative lookup offset
      # - { 'topic1' => { 0 => 5 } } - names with exact partitions offsets
      # - { 'topic1' => { 0 => -5 }, 'topic2' => { 1 => 5 } } - with per partition negative offsets
      #
      # @param topics [Array, Hash] topics definitions
      # @return [Hash] hash with topics containing partitions definitions
      def expand_topics_with_partitions(topics)
        # Simplification for the single topic case
        topics = [topics] if topics.is_a?(String)
        # If we've got just array with topics, we need to convert that into a representation
        # that we can expand with offsets
        topics = topics.map { |name| [name, false] }.to_h if topics.is_a?(Array)

        expanded = Hash.new { |h, k| h[k] = {} }

        topics.map do |topic, details|
          if details.is_a?(Hash)
            details.each do |partition, offset|
              expanded[topic][partition] = offset
            end
          else
            partition_count(topic.to_s).times do |partition|
              # If no offsets are provided, we just start from zero
              expanded[topic][partition] = details || 0
            end
          end
        end

        expanded
      end

      # @param timeout [Integer] timeout in ms
      # @return [Rdkafka::Consumer::Message, nil] message or nil if nothing to do
      def poll(timeout)
        @current_consumer.poll(timeout)
      rescue Rdkafka::RdkafkaError => e
        # End of partition
        if e.code == :partition_eof
          @stopped_partitions += 1

          retry
        end

        raise e
      end

      # Converts raw rdkafka message into Karafka message
      #
      # @param message [Rdkafka::Consumer::Message] raw rdkafka message
      # @return [::Karafka::Messages::Message]
      def build_message(message)
        Messages::Builders::Message.call(
          message,
          @routing_topics.fetch(message.topic),
          Time.now
        )
      end

      # Do we have all the data we wanted or did every topic partition has reached eof.
      # @return [Boolean]
      def done?
        @stopped_partitions >= @total_partitions
      end

      # Builds the tpl representing all the subscriptions we want to run
      #
      # Additionally for negative offsets, does the watermark calculation where to start
      #
      # @param consumer [Rdkafka::Consumer] consumer we need in case of negative offsets as
      #   negative are going to be used to do "give me last X". We use the already initialized
      #   consumer instance, not to start another one again.
      # @return [Rdkafka::Consumer::TopicPartitionList]
      def tpl_with_expanded_offsets(consumer)
        tpl = Rdkafka::Consumer::TopicPartitionList.new

        @topics_with_partitions.each do |name, partitions|
          partitions_with_offsets = {}

          # When no offsets defined, we just start from zero
          if partitions.is_a?(Array) || partitions.is_a?(Range)
            partitions_with_offsets = partitions.map { |partition| [partition, 0] }.to_h
          else
            # When offsets defined, we can either use them if positive or expand and move back
            # in case of negative (-1000 means last 1000 messages, etc)
            partitions.each do |partition, offset|
              if offset.negative?
                _, high_watermark_offset = consumer.query_watermark_offsets(name, partition)
                # We add because this offset is negative
                partitions_with_offsets[partition] = high_watermark_offset + offset
              else
                partitions_with_offsets[partition] = offset
              end
            end
          end

          tpl.add_topic_and_partitions_with_offsets(name, partitions_with_offsets)
        end

        tpl
      end

      # @param name [String] topic name
      # @return [Integer] number of partitions of the topic we want to iterate over
      def partition_count(name)
        Admin
          .cluster_info
          .topics
          .find { |topic| topic.fetch(:topic_name) == name }
          .fetch(:partitions)
          .count
      end
    end
  end
end

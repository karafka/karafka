# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Topic iterator allows you to iterate over topic/partition data and perform lookups for
    # information that you need.
    #
    # It supports early stops on finding the requested data and allows for seeking till
    # the end. It also allows for signaling, when a given message should be last out of certain
    # partition, but we still want to continue iterating in other messages.
    #
    # It does **not** create a consumer group and does not have any offset management until first
    # consumer offset marking happens. So can be use for quick seeks as well as iterative,
    # repetitive data fetching from rake, etc.
    class Iterator
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
      # @param max_wait_time [Integer] max wait in ms when iterator did not receive any messages
      #
      # @note It is worth keeping in mind, that this API also needs to operate within
      #   `max.poll.interval.ms` limitations on each iteration
      #
      # @note In case of a never-ending iterator, you need to set `enable.partition.eof` to `false`
      #   so we don't stop polling data even when reaching the end (end on a given moment)
      def initialize(
        topics,
        settings: { 'auto.offset.reset': 'beginning' },
        yield_nil: false,
        max_wait_time: 200
      )
        @topics_with_partitions = Expander.new.call(topics)

        @routing_topics = @topics_with_partitions.map do |name, _|
          [name, ::Karafka::Routing::Router.find_or_initialize_by_name(name)]
        end.to_h

        @total_partitions = @topics_with_partitions.map(&:last).sum(&:count)

        @stopped_partitions = 0

        @settings = settings
        @yield_nil = yield_nil
        @max_wait_time = max_wait_time
      end

      # Iterates over requested topic partitions and yields the results with the iterator itself
      # Iterator instance is yielded because one can run `stop_partition` to stop iterating over
      # part of data. It is useful for scenarios where we are looking for some information in all
      # the partitions but once we found it, given partition data is no longer needed and would
      # only eat up resources.
      def each
        Admin.with_consumer(@settings) do |consumer|
          tpl = TplBuilder.new(consumer, @topics_with_partitions).call
          consumer.assign(tpl)

          # We need this for self-referenced APIs like pausing
          @current_consumer = consumer

          # Stream data until we reach the end of all the partitions or until the end user
          # indicates that they are done
          until done?
            message = poll

            # Skip nils if not explicitly required
            next if message.nil? && !@yield_nil

            if message
              @current_message = build_message(message)

              yield(@current_message, self)
            else
              yield(nil, self)
            end
          end

          @current_consumer.commit_offsets(async: false) if @stored_offsets
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
            name => [Rdkafka::Consumer::Partition.new(partition, 0)]
          )
        )
      end

      # Stops all the iterating
      # @note `break` can also be used but in such cases commits stored async will not be flushed
      #   to Kafka. This is why `#stop` is the recommended method.
      def stop
        @stopped = true
      end

      # Marks given message as consumed.
      #
      # @param message [Karafka::Messages::Message] message that we want to mark as processed
      def mark_as_consumed(message)
        @current_consumer.store_offset(message, nil)
        @stored_offsets = true
      end

      # Marks given message as consumed and commits offsets
      #
      # @param message [Karafka::Messages::Message] message that we want to mark as processed
      def mark_as_consumed!(message)
        mark_as_consumed(message)
        @current_consumer.commit_offsets(async: false)
      end

      private

      # @return [Rdkafka::Consumer::Message, nil] message or nil if nothing to do
      def poll
        @current_consumer.poll(@max_wait_time)
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
        (@stopped_partitions >= @total_partitions) || @stopped
      end
    end
  end
end

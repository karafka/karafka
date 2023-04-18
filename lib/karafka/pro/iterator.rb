# frozen_string_literal: true

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
      # A simple API allowing to iterate over topic/partition data, without having to subscribe
      # and deal with rebalances. This API allows for multi-partition streaming and is optimized
      # for data lookups. It allows for explicit stopping iteration over any partition during
      # the iteration process, allowing for optimized lookups.
      #
      # @param name [String] name of the topic from which we want to get the data
      # @param partitions [Array<Integer>, Range, Hash<Integer, Integer>] Array or range with
      #   partitions to which we want to subscribe or a hash with keys with partitions and values
      #   with initial offsets.
      # @param settings [Hash] extra settings for the consumer. Please keep in mind, that if
      #   overwritten, you may want to include `auto.offset.reset` to match your case.
      #
      # @note It is worth keeping in mind, that this API also needs to operate within
      #   `max.poll.interval.ms` limitations on each iteration
      #
      # @note In case of a never-ending iterator, you need to set `enable.partition.eof` to `false`
      #   so we don't stop polling data even when reaching the end (end on a given moment)
      def initialize(name, partitions = [], settings = { 'auto.offset.reset': 'beginning' })
        @name = name.to_s
        @topic = ::Karafka::Routing::Router.find_or_initialize_by_name(@name)
        @partitions = partitions.empty? ? (0..partition_count - 1) : partitions
        @stopped_partitions = 0
        @settings = settings
      end

      # Iterates over requested topic partitions and yields the results with the iterator itself
      # Iterator instance is yielded because one can run `stop_partition` to stop iterating over
      # part of data. It is useful for scenarios where we are looking for some information in all
      # the partitions but once we found it, given partition data is no longer needed and would
      # only eat up resources.
      def each
        Admin.with_consumer(@settings) do |consumer|
          consumer.assign(tpl)

          # We need this for self-referenced APIs like pausing
          @current_consumer = consumer

          # Stream data until we reach the end of all the partitions or until the end user
          # indicates that they are done
          until done?
            message = poll(200)

            next unless message

            yield(
              build_message(message), self
            )
          end

          @current_consumer = nil
        end

        # Reset so we can use the same iterator again if needed
        @stopped_partitions = 0
      end

      # Stops processing of a given partition
      # We expect the partition to be provided because of a scenario, where there is a
      # multi-partition iteration and we want to stop a different partition that the one that
      # is currently yielded.
      #
      # We pause it forever and no longer work with it.
      #
      # @param partition [Integer] partition we want to stop processing
      def stop_partition(partition)
        @stopped_partitions += 1

        @current_consumer.pause(
          Rdkafka::Consumer::TopicPartitionList.new(topic => [partition])
        )
      end

      private

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
          @topic,
          Time.now
        )
      end

      # Do we have all the data we wanted or did every topic partition has reached eof.
      # @return [Boolean]
      def done?
        @stopped_partitions >= @partitions.size
      end

      # Builds the tpl representing all the subscriptions we want to run
      # @return [Rdkafka::Consumer::TopicPartitionList]
      def tpl
        tpl = Rdkafka::Consumer::TopicPartitionList.new

        if @partitions.is_a?(Array) || @partitions.is_a?(Range)
          partitions_with_offsets = @partitions.map { |partition| [partition, 0] }.to_h
          tpl.add_topic_and_partitions_with_offsets(@name, partitions_with_offsets)
        else
          tpl.add_topic_and_partitions_with_offsets(@name, @partitions)
        end

        tpl
      end

      # @return [Integer] number of partitions of the topic we want to iterate over
      def partition_count
        Admin
          .cluster_info
          .topics
          .find { |topic| topic.fetch(:topic_name) == @name }
          .fetch(:partitions)
          .count
      end
    end
  end
end

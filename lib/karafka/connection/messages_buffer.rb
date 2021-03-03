# frozen_string_literal: true

module Karafka
  module Connection
    # Buffer for messages.
    # When message is added to this buffer, it gets assigned to an array with other messages from
    # the same topic and partition.
    #
    # @note This buffer is NOT threadsafe.
    class MessagesBuffer
      attr_reader :size

      # @return [Karafka::Connection::MessagesBuffer] buffer instance
      def initialize
        @size = 0
        @groups = Hash.new do |topic_groups, topic|
          topic_groups[topic] = Hash.new do |partition_groups, partition|
            partition_groups[partition] = []
          end
        end
      end

      # Iterates over aggregated data providing messages per topic partition.
      #
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      # @yieldparam [Array<Rdkafka::Consumer::Message>] topic partition aggregated results
      def each
        @groups.each do |topic, partitions|
          partitions.each do |partition, messages|
            yield(topic, partition, messages)
          end
        end
      end

      # Adds a message to the buffer.
      #
      # @param message [Rdkafka::Consumer::Message] raw rdkafka message
      # @return [Array<Rdkafka::Consumer::Message>] given partition topic sub-buffer array
      def <<(message)
        @size += 1
        @groups[message.topic][message.partition] << message
      end

      # Removes all the data from the buffer.
      #
      # @note We do not clear the whole groups hash but rather we clear the partition hashes, so
      #   we save ourselves some objects allocations. We cannot clear the underlying arrays as they
      #   may be used in other threads for data processing, thus if we would clear it, we could
      #   potentially clear a raw messages array for a job that is in the jobs queue.
      def clear
        @size = 0
        @groups.each_value(&:clear)
      end
    end
  end
end

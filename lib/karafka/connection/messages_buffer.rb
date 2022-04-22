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

      extend Forwardable

      def_delegators :@groups, :each

      # @return [Karafka::Connection::MessagesBuffer] buffer instance
      def initialize
        @size = 0
        @groups = Hash.new do |topic_groups, topic|
          topic_groups[topic] = Hash.new do |partition_groups, partition|
            partition_groups[partition] = []
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

      # Removes given topic and partition data out of the buffer
      # This is used when there's a partition revocation
      # @param topic [String] topic we're interested in
      # @param partition [Integer] partition of which data we want to remove
      def delete(topic, partition)
        return unless @groups.key?(topic)
        return unless @groups.fetch(topic).key?(partition)

        topic_data = @groups.fetch(topic)
        topic_data.delete(partition)

        recount!

        # If there are no more partitions to handle in a given topic, remove it completely
        @groups.delete(topic) if topic_data.empty?
      end

      # Removes duplicated messages from the same partitions
      # This should be used only when rebalance occurs, as we may get data again we already have
      # due to the processing from the last offset. In cases like this, we may get same data
      # again and we do want to ensure as few duplications as possible
      def uniq!
        @groups.each_value do |partitions|
          partitions.each_value do |messages|
            messages.uniq!(&:offset)
          end
        end

        recount!
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

      private

      # Updates the messages count if we performed any operations that could change the state
      def recount!
        @size = @groups.each_value.sum do |partitions|
          partitions.each_value.map(&:count).sum
        end
      end
    end
  end
end

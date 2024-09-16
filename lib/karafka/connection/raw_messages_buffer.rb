# frozen_string_literal: true

module Karafka
  module Connection
    # Buffer for raw librdkafka messages and eof status.
    #
    # When message is added to this buffer, it gets assigned to an array with other messages from
    # the same topic and partition.
    #
    # @note This buffer is NOT threadsafe.
    #
    # @note We store data here in groups per topic partition to handle the revocation case, where
    #    we may need to remove messages from a single topic partition.
    class RawMessagesBuffer
      include Karafka::Core::Helpers::Time

      attr_reader :size

      # @return [Float] last polling time in milliseconds (monotonic)
      attr_reader :last_polled_at

      # @return [Karafka::Connection::MessagesBuffer] buffer instance
      def initialize
        @size = 0
        @last_polled_at = monotonic_now

        @groups = Hash.new do |topic_groups, topic|
          topic_groups[topic] = Hash.new do |partition_groups, partition|
            partition_groups[partition] = {
              eof: false,
              messages: []
            }
          end
        end
      end

      # Adds a message to the buffer.
      #
      # @param message [Rdkafka::Consumer::Message] raw rdkafka message
      # @return [Array<Rdkafka::Consumer::Message>] given partition topic sub-buffer array
      def <<(message)
        @size += 1
        partition_state = @groups[message.topic][message.partition]
        partition_state[:messages] << message
        partition_state[:eof] = false
      end

      # Marks given topic partition as one that reached eof
      # @param topic [String] topic that reached eof
      # @param partition [Integer] partition that reached eof
      def eof(topic, partition)
        @groups[topic][partition][:eof] = true
      end

      # Marks the last polling time that can be accessed via `#last_polled_at`
      def polled
        @last_polled_at = monotonic_now
      end

      # Allows to iterate over all the topics and partitions messages
      #
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      # @yieldparam [Array<Rdkafka::Consumer::Message>] topic partition aggregated results
      # @yieldparam [Boolean] has polling of this partition reach eof
      def each
        @groups.each do |topic, partitions|
          partitions.each do |partition, details|
            yield(topic, partition, details[:messages], details[:eof])
          end
        end
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
          partitions.each_value do |details|
            details[:messages].uniq!(&:offset)
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
      #
      # @note We do not clear the eof assignments because they can span across batch pollings.
      #   Since eof is not raised non-stop and is silenced after an eof poll, if we would clean it
      #   here we would loose the notion of it. The reset state for it should happen when we do
      #   discover new messages for given topic partition.
      def clear
        @size = 0
        @groups.each_value(&:clear)
      end

      private

      # Updates the messages count if we performed any operations that could change the state
      def recount!
        @size = 0

        @groups.each_value do |partitions|
          partitions.each_value do |details|
            @size += details[:messages].size
          end
        end
      end
    end
  end
end

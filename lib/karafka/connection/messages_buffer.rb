# frozen_string_literal: true

module Karafka
  module Connection
    # Buffer used to build and store karafka messages built based on raw librdkafka messages.
    #
    # Why do we have two buffers? `RawMessagesBuffer` is used to store raw messages and to handle
    #   cases related to partition revocation and reconnections. It is "internal" to the listening
    #   process. `MessagesBuffer` on the other hand is used to "translate" those raw messages that
    #   we know that are ok into Karafka messages and to simplify further work with them.
    #
    # While it adds a bit of overhead, it makes conceptual things much easier and it adds only two
    #   simple hash iterations over messages batch.
    #
    # @note This buffer is NOT thread safe. We do not worry about it as we do not use it outside
    #   of the main listener loop. It can be cleared after the jobs are scheduled with messages
    #   it stores, because messages arrays are not "cleared" in any way directly and their
    #   reference stays.
    class MessagesBuffer
      attr_reader :size

      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      def initialize(subscription_group)
        @subscription_group = subscription_group
        @size = 0

        @groups = Hash.new do |topic_groups, topic|
          topic_groups[topic] = Hash.new do |partition_groups, partition|
            partition_groups[partition] = {
              eof: false,
              messages: []
            }
          end
        end
      end

      # Remaps raw messages from the raw messages buffer to Karafka messages
      # @param raw_messages_buffer [RawMessagesBuffer] buffer with raw messages
      def remap(raw_messages_buffer)
        clear

        # Since it happens "right after" we've received the messages, it is close enough it time
        # to be used as the moment we received messages.
        received_at = Time.now
        last_polled_at = raw_messages_buffer.last_polled_at

        raw_messages_buffer.each do |topic, partition, messages, eof|
          @size += messages.size

          ktopic = @subscription_group.topics.find(topic)

          built_messages = messages.map do |message|
            Messages::Builders::Message.call(
              message,
              ktopic,
              received_at
            )
          end

          @groups[topic][partition] = {
            eof: eof,
            messages: built_messages,
            last_polled_at: last_polled_at
          }
        end
      end

      # Allows to iterate over all the topics and partitions messages
      #
      # @yieldparam [String] topic name
      # @yieldparam [Integer] partition number
      # @yieldparam [Array<Karafka::Messages::Message>] messages from a given topic partition
      # @yieldparam [Boolean] true if eof, false otherwise
      # @yieldparam [Float] last polled at monotonic clock time
      def each
        @groups.each do |topic, partitions|
          partitions.each do |partition, details|
            yield(topic, partition, details[:messages], details[:eof], details[:last_polled_at])
          end
        end
      end

      # Checks if there are any messages from a given topic partition in the buffer
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Boolean] true if there is at least one message from this topic partition,
      #   otherwise false
      def present?(topic, partition)
        return false unless @groups.include?(topic)
        return false unless @groups[topic].include?(partition)

        true
      end

      # @return [Boolean] is the buffer empty or does it contain any messages
      def empty?
        @size.zero?
      end

      private

      # Clears the buffer completely
      def clear
        @size = 0
        @groups.clear
      end
    end
  end
end

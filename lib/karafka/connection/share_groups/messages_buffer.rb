# frozen_string_literal: true

module Karafka
  module Connection
    module ShareGroups
      # Buffer used to build and store karafka messages built out of the raw records of a share
      # group poll, grouped per topic partition. Mirrors {Connection::MessagesBuffer} (same
      # `#size` and `#each` API, so the `connection.listener.fetch_loop.received` subscribers work
      # for both group types), without the eof tracking: share groups have no partition ownership
      # and no end-of-partition notion.
      #
      # @note This buffer is NOT thread safe. It is used only from the listener loop and records
      #   arrays are handed over to jobs by reference, so it can be safely remapped afterwards.
      class MessagesBuffer
        include Karafka::Core::Helpers::Time

        attr_reader :size

        # @param subscription_group [Karafka::Routing::SubscriptionGroup]
        def initialize(subscription_group)
          @subscription_group = subscription_group
          @size = 0
          @groups = Hash.new { |topic_groups, topic| topic_groups[topic] = {} }
        end

        # Remaps raw share records to Karafka messages grouped per topic partition
        #
        # @param raw_messages [Array<Rdkafka::ShareConsumer::Message>] records of a poll
        def remap(raw_messages)
          clear
          # Since it happens "right after" we've received the messages, it is close enough it time
          # to be used as the moment we received messages.
          received_at = Time.now
          last_polled_at = monotonic_now

          raw_messages.group_by { |message| [message.topic, message.partition] }.each do |key, raws|
            topic, partition = key
            ktopic = @subscription_group.topics.find(topic)
            @size += raws.size

            built_messages = raws.map do |raw_message|
              message = Messages::Builders::Message.call(raw_message, ktopic, received_at)
              message.metadata.delivery_count = raw_message.delivery_count
              message
            end

            @groups[topic][partition] = {
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
        # @yieldparam [Boolean] always false - share groups have no eof notion
        # @yieldparam [Float] last polled at monotonic clock time
        def each
          @groups.each do |topic, partitions|
            partitions.each do |partition, details|
              yield(topic, partition, details[:messages], false, details[:last_polled_at])
            end
          end
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
end

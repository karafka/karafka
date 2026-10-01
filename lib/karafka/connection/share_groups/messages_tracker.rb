# frozen_string_literal: true

module Karafka
  module Connection
    module ShareGroups
      # Tracks share-group records that were delivered by a poll but not acknowledged yet.
      #
      # In the explicit acknowledgement mode librdkafka refuses to poll again until every record of
      # the previous poll is acknowledged, so the client needs to know which records are still
      # outstanding in order to settle them.
      #
      # @note This tracker is not thread-safe on its own. It is used only under the share client
      #   mutex that already serializes every operation on the share consumer.
      class MessagesTracker
        def initialize
          @pending = {}
        end

        # Starts tracking delivered records
        #
        # @param messages [Array<Rdkafka::ShareConsumer::Message>] records delivered by a poll
        def track(messages)
          messages.each { |message| @pending[key(message)] = message }
        end

        # Stops tracking an acknowledged record
        #
        # @param message [Karafka::Messages::Message, Rdkafka::ShareConsumer::Message] record
        def acknowledged(message)
          @pending.delete(key(message))
        end

        # @param message [Karafka::Messages::Message, Rdkafka::ShareConsumer::Message] record
        # @return [Boolean] is the record still not acknowledged
        def pending?(message)
          @pending.key?(key(message))
        end

        # @return [Array<Rdkafka::ShareConsumer::Message>] records that are still not acknowledged
        def pending
          @pending.values
        end

        # @return [Boolean] are there no records waiting for an acknowledgement
        def empty?
          @pending.empty?
        end

        # Stops tracking all the records (for example when the share consumer is closed)
        def clear
          @pending.clear
        end

        private

        # @param message [Karafka::Messages::Message, Rdkafka::ShareConsumer::Message] record
        # @return [Array] key identifying the record within the share group
        def key(message)
          [message.topic, message.partition, message.offset]
        end
      end
    end
  end
end

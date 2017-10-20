# frozen_string_literal: true

module Karafka
  module Persistence
    # Persistence layer to store current thread messages consumer for further use
    class MessagesConsumer
      # Thread.current key under which we store current thread messages consumer
      PERSISTENCE_SCOPE = :messages_consumer

      # @param messages_consumer [Karafka::Connection::MessagesConsumer] messages consumer of
      #   a current thread
      # @return [Karafka::Connection::MessagesConsumer] persisted messages consumer
      def self.write(messages_consumer)
        Thread.current[PERSISTENCE_SCOPE] = messages_consumer
      end

      # @return [Karafka::Connection::MessagesConsumer] persisted messages consumer
      # @raise [Karafka::Errors::MissingMessagesConsumer] raised when no thread messages consumer
      #   but we try to use it anyway
      def self.read
        Thread.current[PERSISTENCE_SCOPE] || raise(Errors::MissingMessagesConsumer)
      end
    end
  end
end

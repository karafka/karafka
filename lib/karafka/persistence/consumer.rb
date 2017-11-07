# frozen_string_literal: true

module Karafka
  module Persistence
    # Persistence layer to store current thread messages consumer for further use
    class Consumer
      # Thread.current key under which we store current thread messages consumer
      PERSISTENCE_SCOPE = :consumer

      # @param consumer [Karafka::Connection::Consumer] messages consumer of
      #   a current thread
      # @return [Karafka::Connection::Consumer] persisted messages consumer
      def self.write(consumer)
        Thread.current[PERSISTENCE_SCOPE] = consumer
      end

      # @return [Karafka::Connection::Consumer] persisted messages consumer
      # @raise [Karafka::Errors::MissingConsumer] raised when no thread messages consumer
      #   but we try to use it anyway
      def self.read
        Thread.current[PERSISTENCE_SCOPE] || raise(Errors::MissingConsumer)
      end
    end
  end
end

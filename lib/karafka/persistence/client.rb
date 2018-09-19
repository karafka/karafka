# frozen_string_literal: true

module Karafka
  module Persistence
    # Persistence layer to store current thread messages consumer client for further use
    class Client
      # Thread.current key under which we store current thread messages consumer client
      PERSISTENCE_SCOPE = :client

      private_constant :PERSISTENCE_SCOPE

      class << self
        # @param client [Karafka::Connection::Client] messages consumer client of
        #   a current thread
        # @return [Karafka::Connection::Client] persisted messages consumer client
        def write(client)
          Thread.current[PERSISTENCE_SCOPE] = client
        end

        # @return [Karafka::Connection::Client] persisted messages consumer client
        # @raise [Karafka::Errors::MissingClientError] raised when no thread messages consumer
        #   client but we try to use it anyway
        def read
          Thread.current[PERSISTENCE_SCOPE] || raise(Errors::MissingClientError)
        end
      end
    end
  end
end

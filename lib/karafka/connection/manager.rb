# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # Connections manager responsible for starting and managing listeners connections
    # In the OSS version it starts listeners as they are without any connection management or
    # resources utilization supervision
    class Manager
      def initialize
        @listeners = []
      end

      # Registers provided listeners and starts them
      #
      # @param listeners [Connection::ListenersBatch]
      def register(listeners)
        @listeners = listeners
        @listeners.each(&:start)
      end
    end
  end
end

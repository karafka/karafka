module Karafka
  # Namespace that encapsulates everything related to connections
  module Connection
    # Single incoming Kafka event instance
    class Event
      attr_reader :topic, :message

      # @param topic [String] topic from which this message comes
      # @param message [String] raw message (not deserialized or anything)
      # @return [Karafka::Connection::Event] event instance
      def initialize(topic, message)
        @topic = topic
        @message = message
      end
    end
  end
end

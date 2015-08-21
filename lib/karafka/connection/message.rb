module Karafka
  # Namespace that encapsulates everything related to connections
  module Connection
    # Single incoming Kafka message instance wrapper
    class Message
      attr_reader :topic, :content

      # @param topic [String] topic from which this message comes
      # @param content [String] raw message content (not deserialized or anything) from Kafka
      # @return [Karafka::Connection::Message] incoming message instance
      def initialize(topic, content)
        @topic = topic
        @content = content
      end
    end
  end
end

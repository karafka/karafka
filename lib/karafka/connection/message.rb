module Karafka
  # Namespace that encapsulates everything related to connections
  module Connection
    # Single incoming Kafka message instance wrapper
    class Message
      attr_reader :content

      # @param topic [String] topic from which this message comes
      # @param content [String] raw message content (not deserialized or anything) from Kafka
      # @return [Karafka::Connection::Message] incoming message instance
      def initialize(topic, content)
        @topic = topic.to_s
        @content = content
      end

      # Returns topic name
      # @note Appends kafka.topic_prefix config flag if set
      def topic
        prefix = ::Karafka::App.config.kafka.topic_prefix
        !prefix.nil? ? "#{prefix}#{@topic}" : @topic
      end
    end
  end
end

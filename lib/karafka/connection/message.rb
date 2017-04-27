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
      # @note If kafka.topic_mapper is set, the topic will be set to the return
      #       value of that block
      def topic(mapper = ::Karafka::App.config.kafka.topic_mapper)
        mapper.is_a?(Proc) ? mapper.call(@topic).to_s : @topic
      end
    end
  end
end

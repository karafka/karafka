# frozen_string_literal: true

module Karafka
  # Namespace that encapsulates everything related to connections
  module Connection
    # Single incoming Kafka message instance wrapper
    class Message
      # Message attributes
      ATTRIBUTES = %i[
        topic
        content
        partition
        offset
        key
      ].freeze

      ATTRIBUTES.each(&method(:attr_reader))

      # @param topic [String] topic from which this message comes
      # @param kafka_message [Kafka::FetchedMessage] raw kafka message
      # @return [Karafka::Connection::Message] mapped message
      def initialize(topic, kafka_message)
        @topic = topic
        @content = kafka_message.value
        @partition = kafka_message.partition
        @offset = kafka_message.offset
        @key = kafka_message.key
      end

      # @return [Hash] hash with message attributes
      # @example Cast a message to hash
      #   msg.to_h #=> { topic: 'topic', content: 'a', partition: 41, offset: 158, key: nil }
      def to_h
        ATTRIBUTES.map { |name| [name, send(name)] }.to_h
      end
    end
  end
end

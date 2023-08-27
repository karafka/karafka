# frozen_string_literal: true

module Karafka
  module Messages
    # Builders encapsulate logic related to creating messages related objects.
    module Builders
      # Builder of a single message based on raw rdkafka message.
      module Message
        class << self
          # @param kafka_message [Rdkafka::Consumer::Message] raw fetched message
          # @param topic [Karafka::Routing::Topic] topic for which this message was fetched
          # @param received_at [Time] moment when we've received the message
          # @return [Karafka::Messages::Message] message object with payload and metadata
          def call(kafka_message, topic, received_at)
            metadata = Karafka::Messages::Metadata.new(
              timestamp: kafka_message.timestamp,
              headers: kafka_message.headers,
              key: kafka_message.key,
              offset: kafka_message.offset,
              deserializer: topic.deserializer,
              partition: kafka_message.partition,
              topic: topic.name,
              received_at: received_at
            ).freeze

            # Get the raw payload
            payload = kafka_message.payload

            # And nullify it in the kafka message. This can save a lot of memory when used with
            # the Pro Cleaner API
            kafka_message.instance_variable_set('@payload', nil)

            # Karafka messages cannot be frozen because of the lazy deserialization feature
            Karafka::Messages::Message.new(payload, metadata)
          end
        end
      end
    end
  end
end

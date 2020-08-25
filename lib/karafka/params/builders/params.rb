# frozen_string_literal: true

module Karafka
  module Params
    # Due to the fact, that we create params related objects in couple contexts / places
    # plus backends can build up them their own way we have this namespace.
    # It allows to isolate actual params objects from their building process that can be
    # context dependent.
    module Builders
      # Builder for params
      module Params
        class << self
          # @param kafka_message [Kafka::FetchedMessage] message fetched from Kafka
          # @param topic [Karafka::Routing::Topic] topic for which this message was fetched
          # @return [Karafka::Params::Params] params object with payload and message metadata
          def from_kafka_message(kafka_message, topic)
            metadata = Karafka::Params::Metadata.new(
              create_time: kafka_message.create_time,
              headers: kafka_message.headers || {},
              is_control_record: kafka_message.is_control_record,
              key: kafka_message.key,
              offset: kafka_message.offset,
              deserializer: topic.deserializer,
              partition: kafka_message.partition,
              receive_time: Time.now,
              topic: topic.name
            ).freeze

            Karafka::Params::Params.new(
              kafka_message.value,
              metadata
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Params
    # Due to the fact, that we create params related objects in couple contexts / places
    # plus backends can build up them their own way we have this namespace.
    # It allows to isolate actual params objects from their building prcess that can be
    # context dependent.
    module Builders
      # Builder for params
      module Params
        class << self
          # @param kafka_message [Kafka::FetchedMessage] message fetched from Kafka
          # @param topic [Karafka::Routing::Topic] topic for which this message was fetched
          # @return [Karafka::Params::Params] params object
          def from_kafka_message(kafka_message, topic)
            Karafka::Params::Params
              .new
              .merge!(
                'create_time' => kafka_message.create_time,
                'headers' => kafka_message.headers || {},
                'is_control_record' => kafka_message.is_control_record,
                'key' => kafka_message.key,
                'offset' => kafka_message.offset,
                'parser' => topic.parser,
                'partition' => kafka_message.partition,
                'receive_time' => Time.now,
                'topic' => topic.name,
                'value' => kafka_message.value
              )
          end
        end
      end
    end
  end
end

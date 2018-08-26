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
          # @param [Kafka::FetchedMessage] message fetched from Kafka
          # @param [Karafka::Routing::Topic] topic for which this message was fetched
          # @return [Karafka::Params::Params] params object
          def from_kafka_message(message, topic)
            Karafka::Params::Params
              .new
              .merge!(
                'value' => message.value,
                'partition' => message.partition,
                'offset' => message.offset,
                'key' => message.key,
                'create_time' => message.create_time,
                'receive_time' => Time.now,
                'headers' => message.headers || {},
                'topic' => topic.name,
                'parser' => topic.parser
              )
          end
        end
      end
    end
  end
end

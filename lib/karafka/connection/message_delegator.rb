# frozen_string_literal: true

module Karafka
  module Connection
    # Class that delegates processing of a single received message for which we listen to
    # a proper processor
    module MessageDelegator
      class << self
        # Delegates message (does something with it)
        # It will either schedule or run a proper processor action for the incoming message
        # @note This should be looped to obtain a constant delegating of new messages
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_message [<Kafka::FetchedMessage>] raw message from kafka
        def call(group_id, kafka_message)
          topic = Persistence::Topics.fetch(group_id, kafka_message.topic)
          consumer = Persistence::Consumers.fetch(topic, kafka_message.partition)

          Karafka.monitor.instrument(
            'connection.message_delegator.call',
            caller: self,
            consumer: consumer,
            kafka_message: kafka_message
          ) do
            # @note We always get a single message within single delegator, which means that
            # we don't care if user marked it as a batch consumed or not.
            consumer.params_batch = Params::Builders::ParamsBatch.from_kafka_messages(
              [kafka_message],
              topic
            )
            consumer.call
          end
        end
      end
    end
  end
end

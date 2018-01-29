# frozen_string_literal: true

module Karafka
  module Connection
    # Class that delegates processing of messages for which we listen to a proper processor
    module Delegator
      class << self
        # Delegates messages (does something with them)
        # It will either schedule or run a proper processor action for messages
        # @note This should be looped to obtain a constant delegating of new messages
        # @note We catch all the errors here, to make sure that none failures
        #   for a given consumption will affect other consumed messages
        #   If we wouldn't catch it, it would propagate up until killing the thread
        # @note It is a one huge method, because of performance reasons. It is much faster then
        #   using send or invoking additional methods
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages fetched from kafka
        def call(group_id, kafka_messages)
          # @note We always get messages by topic and partition so we can take topic from the
          # first one and it will be valid for all the messages
          topic = Persistence::Topic.fetch(group_id, kafka_messages[0].topic)
          consumer = Persistence::Consumer.fetch(topic, kafka_messages[0].partition)

          Karafka.monitor.instrument(
            'connection.delegator.call',
            caller: self,
            consumer: consumer,
            kafka_messages: kafka_messages
          ) do
            # Depending on a case (persisted or not) we might use new consumer instance per
            # each batch, or use the same one for all of them (for implementing buffering, etc.)
            if topic.batch_consuming
              consumer.params_batch = kafka_messages
              consumer.call
            else
              kafka_messages.each do |kafka_message|
                consumer.params_batch = [kafka_message]
                consumer.call
              end
            end
          end
        end
      end
    end
  end
end

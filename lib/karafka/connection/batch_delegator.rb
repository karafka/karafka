# frozen_string_literal: true

module Karafka
  module Connection
    # Class that delegates processing of batch received messages for which we listen to
    # a proper processor
    module BatchDelegator
      class << self
        # Delegates messages (does something with them)
        # It will either schedule or run a proper processor action for messages
        # @note This should be looped to obtain a constant delegating of new messages
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_batch [<Kafka::FetchedBatch>] raw messages fetched batch
        def call(group_id, kafka_batch)
          topic = Persistence::Topics.fetch(group_id, kafka_batch.topic)
          consumer = Persistence::Consumers.fetch(topic, kafka_batch.partition)

          Karafka.monitor.instrument(
            'connection.batch_delegator.call',
            caller: self,
            consumer: consumer,
            kafka_batch: kafka_batch
          ) do
            # Due to how ruby-kafka is built, we have the metadata that is stored on the batch
            # level only available for batch consuming
            consumer.metadata = Params::Builders::Metadata.from_kafka_batch(kafka_batch, topic)
            kafka_messages = kafka_batch.messages

            # Depending on a case (persisted or not) we might use new consumer instance per
            # each batch, or use the same one for all of them (for implementing buffering, etc.)
            if topic.batch_consuming
              consumer.params_batch = Params::Builders::ParamsBatch.from_kafka_messages(
                kafka_messages,
                topic
              )
              consumer.call
            else
              kafka_messages.each do |kafka_message|
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
  end
end

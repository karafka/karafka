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
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages fetched from kafka
        def call(group_id, kafka_messages)
          # @note We always get messages by topic and partition so we can take topic from the
          # first one and it will be valid for all the messages
          # We map from incoming topic name, as it might be namespaced, etc.
          # @see topic_mapper internal docs
          mapped_topic_name = Karafka::App.config.topic_mapper.incoming(kafka_messages[0].topic)
          topic = Routing::Router.find("#{group_id}_#{mapped_topic_name}")
          consumer = Persistence::Consumer.fetch(topic, kafka_messages[0].partition) do
            topic.consumer.new
          end

          # Depending on a case (persisted or not) we might use new consumer instance per
          # each batch, or use the same one for all of them (for implementing buffering, etc.)
          send(
            topic.batch_consuming ? :delegate_batch : :delegate_each,
            consumer,
            kafka_messages
          )
        end

        private

        # Delegates whole batch in one request (all at once)
        # @param consumer [Karafka::BaseConsumer] base consumer descendant
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def delegate_batch(consumer, kafka_messages)
          consumer.params_batch = kafka_messages
          Karafka.monitor.notice(self, kafka_messages)
          consumer.call
        end

        # Delegates messages one by one (like with std http requests)
        # @param consumer [Karafka::BaseConsumer] base consumer descendant
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def delegate_each(consumer, kafka_messages)
          kafka_messages.each do |kafka_message|
            # @note This is a simple trick - we just delegate one after another, but in order
            # not to handle everywhere both cases (single vs batch), we just "fake" batching with
            # a single message for each
            delegate_batch(consumer, [kafka_message])
          end
        end
      end
    end
  end
end

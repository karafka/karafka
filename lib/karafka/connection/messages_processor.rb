# frozen_string_literal: true

module Karafka
  module Connection
    # Class that consumes messages for which we listen
    module MessagesProcessor
      class << self
        # Processes messages (does something with them)
        # It will either schedule or run a proper controller action for messages
        # @note This should be looped to obtain a constant listening
        # @note We catch all the errors here, to make sure that none failures
        #   for a given consumption will affect other consumed messages
        #   If we wouldn't catch it, it would propagate up until killing the Celluloid actor
        # @param group_id [String] group_id of a group from which a given message came
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages fetched from kafka
        def process(group_id, kafka_messages)
          controller = Karafka::Routing::Router.build(group_id, kafka_messages[0])
          handler = controller.topic.batch_processing ? :process_batch : :process_each
          send(handler, controller, kafka_messages)
        end

        private

        # Processes whole batch in one request (all at once)
        # @param controller [Karafka::BaseController] base controller descendant
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def process_batch(controller, kafka_messages)
          controller.params_batch = kafka_messages
          Karafka.monitor.notice(self, kafka_messages)
          controller.schedule
        end

        # Processes messages one by one (like with std http requests)
        # @param controller [Karafka::BaseController] base controller descendant
        # @param kafka_messages [Array<Kafka::FetchedMessage>] raw messages from kafka
        def process_each(controller, kafka_messages)
          kafka_messages.each do |kafka_message|
            # @note This is a simple trick - we just process one after another, but in order
            # not to handle everywhere both cases (single vs batch), we just "fake" batching with
            # a single message for each
            process_batch(controller, [kafka_message])
          end
        end
      end
    end
  end
end

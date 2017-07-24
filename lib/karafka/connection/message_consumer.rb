# frozen_string_literal: true

module Karafka
  module Connection
    # Class that consumes messages for which we listen
    module MessageConsumer
      # Consumes a message (does something with it)
      # It will execute a scheduling task from a proper controller based on a message topic
      # @note This should be looped to obtain a constant listening
      # @note We catch all the errors here, to make sure that none failures
      #   for a given consumption will affect other consumed messages
      #   If we would't catch it, it would propagate up until killing the Celluloid actor
      # @param kafka_message [Kafka::FetchedMessage] raw message that was fetched by kafka
      def self.consume(group_id, kafka_message)
        # We map from incoming topic name, as it might be namespaced, etc.
        # @see topic_mapper internal docs
        mapped_topic = Karafka::App.config.topic_mapper.incoming(kafka_message.topic)
        # @note We search based on the topic id - that is a combination of group id and topic name
        controller = Karafka::Routing::Router.new("#{group_id}_#{mapped_topic}").build
        # We wrap it around with our internal message format, so we don't pass around
        # a raw Kafka message (especially because it contains non-mapped topic name)
        message = Message.new(mapped_topic, kafka_message)
        controller.params = message

        Karafka.monitor.notice(self, message)

        controller.schedule
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self, e)
      end
    end
  end
end

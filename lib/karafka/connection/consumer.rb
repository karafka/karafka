module Karafka
  module Connection
    # Class that consumes messages for which we listen
    class Consumer
      # Consumes a message (does something with it)
      # It will execute a scheduling task from a proper controller based on a message topic
      # @note This should be looped to obtain a constant listening
      # @note We catch all the errors here, to make sure that none failures
      #   for a given consumption will affect other consumed messages
      #   If we would't catch it, it would propagate up until killing the Celluloid actor
      # @param message [Kafka::FetchedMessage] message that was fetched by kafka
      def consume(message)
        # We map from incoming topic name, as it might be namespaced, etc.
        # @see topic_mapper internal docs
        mapped_topic = Karafka::App.config.topic_mapper.incoming(message.topic)

        controller = Karafka::Routing::Router.new(mapped_topic).build
        # We wrap it around with our internal message format, so we don't pass around
        # a raw Kafka message
        controller.params = Message.new(mapped_topic, message.value)

        Karafka.monitor.notice(self.class, controller.to_h)

        controller.schedule
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self.class, e)
      end
    end
  end
end

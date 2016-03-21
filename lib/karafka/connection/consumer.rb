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
      # @param message [Poseidon::FetchedMessage] message that was fetched by poseidon
      def consume(message)
        controller = Karafka::Routing::Router.new(message.topic).build
        # We wrap it around with our internal message format, so we don't pass around
        # a raw Poseidon message
        controller.params = Message.new(message.topic, message.value)

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

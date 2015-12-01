module Karafka
  module Connection
    # Class that consumes messages for which we listen
    class Consumer
      # Consumes a message (does something with it)
      # It will route a message to a proper controller and execute it
      # Logic in this method will be executed for each incoming message
      # @note This should be looped to obtain a constant listening
      # @note We catch all the errors here, to make sure that none failures
      #   for a given consumption will affect other consumed messages
      #   If we would't catch it, it would propagate up until killing the Celluloid actor
      # @param controller_class [Karafka::BaseController] base controller descendant class
      # @param message [Poseidon::FetchedMessage] message that was fetched by poseidon
      def consume(controller_class, message)
        controller = Karafka::Routing::Router.new(
          Message.new(controller_class.topic, message.value)
        ).build

        Karafka.monitor.notice(
          self.class,
          controller_class: controller_class
        )

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

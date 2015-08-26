module Karafka
  module Connection
    # Class that consumes messages for which we listen
    class Consumer
      # Consumes a message (does something with it)
      # It will route a message to a proper controller and execute it
      # Logic in this method will be executed for each incoming message
      # @note This should be looped to obtain a constant listening
      # @param controller [Karafka::BaseController] base controller descendant
      # @param message [Poseidon::FetchedMessage] message that was fetched by poseidon
      def consume(controller, message)
        Karafka.logger.info("Consuming message for #{controller}")

        controller = Karafka::Routing::Router.new(
          Message.new(controller.topic, message.value)
        ).build

        controller.call
      end
    end
  end
end

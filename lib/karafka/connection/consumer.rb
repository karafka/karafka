module Karafka
  module Connection
    # Class that consumes messages for which we listen
    class Consumer
      # Performs a single fetch of all listeners one by one
      # @note This should be looped to obtain a constant listening
      def fetch
        listeners.each do |listener|
          Karafka.logger.info("Listening to #{listener.controller}")

          listener.fetch do |message|
            Karafka.logger.info("Handling message for #{listener.controller} with #{message}")

            Karafka::Routing::Router.new(message).build.call
          end
        end
      end

      # @return [Array<Karafka::Connection::Listener>] array of listeners
      #   that allow us to fetch data.
      # @note Each listener listens to a single topic
      def listeners
        Karafka::Routing::Mapper.controllers.map do |controller|
          Karafka::Connection::Listener.new(controller)
        end
      end
    end
  end
end

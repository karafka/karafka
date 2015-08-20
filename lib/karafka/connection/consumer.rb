module Karafka
  module Connection
    # Class that consumes events for which we listen
    class Consumer
      # Performs a single fetch of all listeners one by one
      # @note This should be looped to obtain a constant listening
      def fetch
        listeners.each do |listener|
          Karafka::App.logger.info("Listening to #{listener.controller}")

          listener.fetch do |event|
            Karafka::App.logger.info("Handling event for #{listener.controller} with #{event}")

            Karafka::Routing::Router.new(event).build.call
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

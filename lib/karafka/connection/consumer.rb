module Karafka
  module Connection
    # Class that consumes messages for which we listen
    class Consumer
      # Performs a single fetch of all listeners one by one
      # @note This should be looped to obtain a constant listening
      def fetch
        listeners.each do |listener|
          Karafka.logger.info("Listening to #{listener.controller}")

          listener.async.fetch_loop(message_action(listener))
        end
      end

      private

      # @return [Array<Karafka::Connection::Listener>] array of listeners
      #   that allow us to fetch data.
      # @note Each listener listens to a single topic
      def listeners
        @listeners ||= Karafka::Routing::Mapper.controllers.map do |controller|
          Karafka::Connection::Listener.new(controller)
        end
      end

      # @return [Proc] action that should be taken upon each incoming message
      def message_action(listener)
        lambda do |message|
          Karafka.logger.info("Handling message for #{listener.controller}")
          Karafka::Routing::Router.new(message).build.call
        end
      end
    end
  end
end

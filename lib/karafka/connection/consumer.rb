module Karafka
  module Connection
    # Class that consumes events for which we listen
    class Consumer
      # Validates on topic and group names uniqueness among all descendants of BaseController.
      # Loop through each consumer group to receive data.
      def call
        loop { fetch }
      end

      private

      # Performs a single fetch of all listeners one by one
      # @note This should be looped to obtain a constant listening
      def fetch
        listeners.each do |listener|
          listener.fetch do |event|
            Karafka::Routing::Router.new(event).call
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

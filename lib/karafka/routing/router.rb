module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper controllers
    # @note Since Kafka does not provide namespaces or modules for topics, they all have "flat"
    #  structure so all the routes are being stored in a single level array
    class Router
      # @param topic [String] topic based on which we find a proper route
      # @return [Karafka::Router] router instance
      def initialize(topic)
        @topic = topic
      end

      # Builds a controller instance that should handle message from a given topic
      # @return [Karafka::BaseController] base controller descendant instance object
      def build
        route.controller.new.tap do |ctrl|
          Karafka::Routing::Route::ATTRIBUTES.each do |attr|
            ctrl.public_send(:"#{attr}=", route.public_send(attr))
          end
        end
      end

      private

      # @return [Karafka::Routing::Route] proper route details
      # @raise [Karafka::Topic::NonMatchingTopicError] raised if topic name does not match
      #   any route defined by user using routes.draw
      def route
        App.routes.find { |route| route.topic == @topic } ||
          raise(Errors::NonMatchingRouteError, @topic)
      end
    end
  end
end

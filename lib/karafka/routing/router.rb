module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming events to proper controllers
    class Router
      # Raised when router receives topic name which is not provided for any of
      #  controllers(inherited from Karafka::BaseController)
      # This should never happen because we listed only to topics defined in controllers
      # but theory is not always right. If you encounter this error - please contact
      # Karafka maintainers
      class NonMatchingTopicError < StandardError; end

      # @param event [Karafka::Connection::Event] single incoming event
      # @return [Karafka::Router] router instance
      def initialize(event)
        @event = event
      end

      # @raise [Karafka::Topic::NonMatchingTopicError] raised if topic name is not match any
      # topic of descendants of Karafka::BaseController
      # Forwards message to controller inherited from Karafka::BaseController based on it's topic
      # and run it
      def call
        descendant = Karafka::Routing::Mapper.by_topics[@event.topic.to_sym]

        fail NonMatchingTopicError unless descendant

        controller = descendant.new
        controller.params = JSON.parse(@event.message)
        controller.call
      end
    end
  end
end

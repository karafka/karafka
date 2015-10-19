module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper controllers
    class Router
      # @param message [Karafka::Connection::Message] single incoming message
      # @return [Karafka::Router] router instance
      def initialize(message)
        @message = message
      end

      # @raise [Karafka::Topic::NonMatchingTopicError] raised if topic name is not match any
      # topic of descendants of Karafka::BaseController
      # Forwards message to controller inherited from Karafka::BaseController based on it's topic
      # and run it
      def build
        descendant = Karafka::Routing::Mapper.by_topics[@message.topic.to_sym]

        fail Errors::NonMatchingTopicError, @message.topic unless descendant

        controller = descendant.new
        controller.params = Karafka::Params.build(@message, descendant.parser)

        controller
      end
    end
  end
end

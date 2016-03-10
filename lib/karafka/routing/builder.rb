module Karafka
  module Routing
    # Routes builder used as a DSL layer for drawing and describing routes
    # @example Build a simple (most common) route
    #   draw do
    #     topic :new_videos do
    #       controller NewVideosController
    #     end
    #   end
    class Builder < Array
      include Singleton

      # Options that are being set on the route level
      ROUTE_OPTIONS = %i(
        group
        worker
        controller
        parser
        interchanger
      ).freeze

      # All those options should be set on the route level
      ROUTE_OPTIONS.each do |option|
        define_method option do |value|
          @current_route.public_send :"#{option}=", value
        end
      end

      # Creates a new route for a given topic and evalues provided block in builder context
      # @param topic [String, Symbol] Kafka topic name
      # @param block [Proc] block that will be evaluated in current context
      # @note Creating new topic means creating a new route
      # @example Define controller for a topic
      #   topic :xyz do
      #     controller XyzController
      #   end
      def topic(topic, &block)
        @current_route = Route.new
        @current_route.topic = topic

        instance_eval(&block)

        store!
      end

      # Used to draw routes for Karafka
      # @note After it is done drawing it will store and validate all the routes to make sure that
      #   they are correct and that there are no topic/group duplications (this is forbidden)
      # @yield Evaluates provided block in a builder context so we can describe routes
      # @example
      #   draw do
      #     topic :xyz do
      #     end
      #   end
      def draw(&block)
        instance_eval(&block)
      end

      private

      # Stores current route locally after it was built and validated
      def store!
        @current_route.build
        @current_route.validate!

        self << @current_route

        validate! :topic, Errors::DuplicatedTopicError
        validate! :group, Errors::DuplicatedGroupError
      end

      # Checks that among all routes a given attribute value is unique
      # @param attribute [Symbol] what routes attribute we want to check for uniqueness
      # @param error [Class] error class that should be raised when something is wrong
      def validate!(attribute, error)
        map = each_with_object({}) do |route, amounts|
          key = route.public_send(attribute)
          amounts[key] = amounts[key].to_i + 1
          amounts
        end

        wrong = map.find { |_, amount| amount > 1 }

        raise error, wrong if wrong
      end
    end
  end
end

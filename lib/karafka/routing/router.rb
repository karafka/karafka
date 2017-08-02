# frozen_string_literal: true

module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper controllers
    # @note Since Kafka does not provide namespaces or modules for topics, they all have "flat"
    #  structure so all the routes are being stored in a single level array
    module Router
      # Builds a controller instance that should handle message from a given topic
      # @param topic_id [String] topic based on which we find a proper route
      # @return [Karafka::BaseController] base controller descendant instance object
      def build(topic_id)
        topic = find(topic_id)
        topic.controller.new.tap { |ctrl| ctrl.topic = topic }
      end

      private

      # @return [Karafka::Routing::Route] proper route details
      # @raise [Karafka::Topic::NonMatchingTopicError] raised if topic name does not match
      #   any route defined by user using routes.draw
      def find(topic_id)
        App.consumer_groups.each do |consumer_group|
          consumer_group.topics.each do |topic|
            return topic if topic.id == topic_id
          end
        end

        raise(Errors::NonMatchingRouteError, topic_id)
      end

      module_function :build
      module_function :find
    end
  end
end

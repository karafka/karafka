# frozen_string_literal: true

module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper consumers
    # @note Since Kafka does not provide namespaces or modules for topics, they all have "flat"
    #  structure so all the routes are being stored in a single level array
    module Router
      # Find a proper topic based on full topic id
      # @param topic_id [String] proper topic id (already mapped, etc) for which we want to find
      #   routing topic
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

      module_function :find
    end
  end
end

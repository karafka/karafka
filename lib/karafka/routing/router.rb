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
      # @return [Karafka::Routing::Topic] proper route details
      # @raise [Karafka::Topic::NonMatchingTopicError] raised if topic name does not match
      #   any route defined by user using routes.draw
      def find(topic_id)
        find_by(id: topic_id) || raise(Errors::NonMatchingRouteError, topic_id)
      end

      # Finds first reference of a given topic based on provided lookup attribute
      # @param lookup [Hash<Symbol, String>] hash with attribute - value key pairs
      # @return [Karafka::Routing::Topic, nil] proper route details or nil if not found
      def find_by(lookup)
        App.consumer_groups.each do |consumer_group|
          consumer_group.topics.each do |topic|
            return topic if lookup.all? do |attribute, value|
              topic.public_send(attribute) == value
            end
          end
        end

        nil
      end

      module_function :find
      module_function :find_by
    end
  end
end

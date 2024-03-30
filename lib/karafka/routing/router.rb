# frozen_string_literal: true

module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper consumers
    # @note Since Kafka does not provide namespaces or modules for topics, they all have "flat"
    #  structure so all the routes are being stored in a single level array
    module Router
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

      # Finds the topic by name (in any consumer group) and if not present, will built a new
      # representation of the topic with the defaults and default deserializers.
      #
      # This is used in places where we may operate on topics that are not part of the routing
      # but we want to do something on them (display data, iterate over, etc)
      # @param name [String] name of the topic we are looking for
      # @return [Karafka::Routing::Topic]
      #
      # @note Please note, that in case of a new topic, it will have a newly built consumer group
      #   as well, that is not part of the routing.
      def find_or_initialize_by_name(name)
        existing_topic = find_by(name: name)

        return existing_topic if existing_topic

        virtual_topic = Topic.new(name, ConsumerGroup.new(name))

        Karafka::Routing::Proxy.new(
          virtual_topic,
          Karafka::App.config.internal.routing.builder.defaults
        ).target
      end

      module_function :find_by
      module_function :find_or_initialize_by_name
    end
  end
end

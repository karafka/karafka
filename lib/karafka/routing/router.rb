# frozen_string_literal: true

module Karafka
  # Namespace for all elements related to requests routing
  module Routing
    # Karafka framework Router for routing incoming messages to proper controllers
    # @note Since Kafka does not provide namespaces or modules for topics, they all have "flat"
    #  structure so all the routes are being stored in a single level array
    module Router
      # Builds a controller instance that should handle message from a given topic.
      # If we don't want to have persistent controllers, we will always build a new one for a given
      # messages batch, but in case of persisted controllers, it will build a long running
      # controller for each topic partition (one during the whole app lifecycle)
      #
      # @param group_id [String] group_id
      # @param kafka_message [Kafka::FetchedMessage] first fetched message from a batch, used to
      #   extract topic and partition
      # @return [Karafka::BaseController] base controller descendant instance object
      def build(group_id, kafka_message)
        # @note We always get messages by topic and partition so we can take topic from the
        # first one and it will be valid for all the messages
        # We map from incoming topic name, as it might be namespaced, etc.
        # @see topic_mapper internal docs
        mapped_topic = Karafka::App.config.topic_mapper.incoming(kafka_message.topic)

        # @note We search based on the topic id - that is a combination of group id and topic name
        topic = find("#{group_id}_#{mapped_topic}")

        if topic.persistent
          # If this is a persistent one, fetch if for current thread, but be aware, that we can get
          # messages for multiple partitions, so we need to have a partition scope in mind as well
          Thread.current[mapped_topic] ||= {}
          Thread.current[mapped_topic][kafka_message.partition] ||= topic.controller.new
        else
          topic.controller.new
        end
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

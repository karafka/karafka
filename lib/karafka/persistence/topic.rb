# frozen_string_literal: true

module Karafka
  module Persistence
    # Local cache for routing topics
    # We use it in order not to build string instances and remap incoming topic upon each
    # message / message batches received
    class Topic
      # Thread.current scope under which we store topics data
      PERSISTENCE_SCOPE = :topics

      # @param group_id [String] group id for which we fetch a topic representation
      # @param raw_topic_name [String] raw topic name (before remapping) for which we fetch a
      #   topic representation
      # @return [Karafka::Routing::Topic] remapped topic representation that can be used further
      #   on when working with given parameters
      def self.fetch(group_id, raw_topic_name)
        Thread.current[PERSISTENCE_SCOPE] ||= Hash.new { |hash, key| hash[key] = {} }

        Thread.current[PERSISTENCE_SCOPE][group_id][raw_topic_name] ||= begin
          # We map from incoming topic name, as it might be namespaced, etc.
          # @see topic_mapper internal docs
          mapped_topic_name = Karafka::App.config.topic_mapper.incoming(raw_topic_name)
          Routing::Router.find("#{group_id}_#{mapped_topic_name}")
        end
      end
    end
  end
end

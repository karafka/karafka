# frozen_string_literal: true

module Karafka
  module Persistence
    # Local cache for routing topics
    # We use it in order not to build string instances and remap incoming topic upon each
    # message / message batches received
    class Topics
      # Thread.current scope under which we store topics data
      PERSISTENCE_SCOPE = :topics

      private_constant :PERSISTENCE_SCOPE

      class << self
        # @return [Concurrent::Hash] hash with all the topics from given groups
        def current
          Thread.current[PERSISTENCE_SCOPE] ||= Concurrent::Hash.new do |hash, key|
            hash[key] = Concurrent::Hash.new
          end
        end

        # @param group_id [String] group id for which we fetch a topic representation
        # @param raw_topic_name [String] raw topic name (before remapping) for which we fetch a
        #   topic representation
        # @return [Karafka::Routing::Topics] remapped topic representation that can be used further
        #   on when working with given parameters
        def fetch(group_id, raw_topic_name)
          current[group_id][raw_topic_name] ||= begin
            # We map from incoming topic name, as it might be namespaced, etc.
            # @see topic_mapper internal docs
            mapped_topic_name = Karafka::App.config.topic_mapper.incoming(raw_topic_name)
            Routing::Router.find("#{group_id}_#{mapped_topic_name}")
          end
        end

        # Clears the whole topics cache for all the threads
        # This is used for in-development code reloading as we need to get rid of all the
        # preloaded and cached instances of objects to make it work
        def clear
          Thread
            .list
            .select { |thread| thread[PERSISTENCE_SCOPE] }
            .each { |thread| thread[PERSISTENCE_SCOPE].clear }
        end
      end
    end
  end
end

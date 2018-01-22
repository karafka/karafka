# frozen_string_literal: true

module Karafka
  module Persistence
    class Topic
      # Local cache for routing topics
      # We use it in order not to build string instances and remap incoming topic upon each
      # message / message batches received
      # @todo
      def self.fetch(group_id, topic)
        @base ||= Concurrent::Hash.new { |h, k| h[k] = Concurrent::Hash.new }

        @base[group_id][topic] ||= begin
          # We map from incoming topic name, as it might be namespaced, etc.
          # @see topic_mapper internal docs
          mapped_topic_name = Karafka::App.config.topic_mapper.incoming(topic)
          Routing::Router.find("#{group_id}_#{mapped_topic_name}")
        end
      end
    end
  end
end

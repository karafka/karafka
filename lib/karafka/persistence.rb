# frozen_string_literal: true

module Karafka
  # Module used to provide a persistent cache across batch requests for a given
  # topic and partition to store some additional details when the persistent mode
  # for a given topic is turned on
  module Persistence
    # @param topic [Karafka::Routing::Topic] topic instance for which we might cache
    # @param partition [Integer] number of partition for which we want to cache
    # @param resource [Symbol] name of the resource that we want to store
    def self.fetch(topic, partition, resource)
      return yield unless topic.persistent
      Thread.current[topic.id] ||= {}
      Thread.current[topic.id][partition] ||= {}
      Thread.current[topic.id][partition][resource] ||= yield
    end
  end
end

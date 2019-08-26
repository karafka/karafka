# frozen_string_literal: true

module Karafka
  # Module used to provide a persistent cache layer for Karafka components that need to be
  # shared inside of a same thread
  module Persistence
    # Module used to provide a persistent cache across batch requests for a given
    # topic and partition to store some additional details when the persistent mode
    # for a given topic is turned on
    class Consumers
      # Thread.current scope under which we store consumers data
      PERSISTENCE_SCOPE = :consumers

      private_constant :PERSISTENCE_SCOPE

      class << self
        # @return [Hash] current thread's persistence scope hash with all the consumers
        def current
          Thread.current[PERSISTENCE_SCOPE] ||= Concurrent::Hash.new do |hash, key|
            hash[key] = Concurrent::Hash.new
          end
        end

        # Used to build (if block given) and/or fetch a current consumer instance that will be
        #   used to process messages from a given topic and partition
        # @param topic [Karafka::Routing::Topic] topic instance for which we might cache
        # @param partition [Integer] number of partition for which we want to cache
        # @return [Karafka::BaseConsumer] base consumer descendant
        def fetch(topic, partition)
          current[topic][partition] ||= topic.consumer.new(topic)
        end

        # Removes all persisted instances of consumers from the consumer cache
        # @note This is used to reload consumers instances when code reloading in development mode
        #   is present. This should not be used in production.
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

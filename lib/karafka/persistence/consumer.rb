# frozen_string_literal: true

module Karafka
  # Module used to provide a persistent cache layer for Karafka components that need to be
  # shared inside of a same thread
  module Persistence
    # Module used to provide a persistent cache across batch requests for a given
    # topic and partition to store some additional details when the persistent mode
    # for a given topic is turned on
    class Consumer
      # Thread.current scope under which we store consumers data
      PERSISTENCE_SCOPE = :consumers

      class << self
        # @return [Hash] current thread persistence scope hash with all the consumers
        def all
          # @note This does not need to be threadsafe (Hash) as it is always executed in a
          # current thread context
          Thread.current[PERSISTENCE_SCOPE] ||= Hash.new { |hash, key| hash[key] = {} }
        end

        # Used to build (if block given) and/or fetch a current consumer instance that will be
        #   used to process messages from a given topic and partition
        # @return [Karafka::BaseConsumer] base consumer descendant
        # @param topic [Karafka::Routing::Topic] topic instance for which we might cache
        # @param partition [Integer] number of partition for which we want to cache
        def fetch(topic, partition)
          # We always store a current instance for callback reasons
          if topic.persistent
            all[topic][partition] ||= topic.consumer.new
          else
            all[topic][partition] = topic.consumer.new
          end
        end
      end
    end
  end
end

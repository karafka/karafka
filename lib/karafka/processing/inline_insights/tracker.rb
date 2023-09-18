# frozen_string_literal: true

module Karafka
  module Processing
    module InlineInsights
      # Object used to t
      #
      # We use a single tracker because we do not need state management here as our consumer groups
      # clients identified by statistics name value are unique. On top of that, having a per
      # process one that is a singleton allows us to use tracker easily also from other places like
      # filtering API etc.
      class Tracker
        include Singleton

        # Empty hash we want to return in any case where we could not locate appropriate topic
        # partition statistics.
        EMPTY_HASH = {}.freeze

        private_constant :EMPTY_HASH

        class << self
          extend Forwardable

          def_delegators :instance, :find, :add, :exists?
        end

        def initialize
          @accu = Hash.new { |h, k| h[k] = {} }
          @mutex = Mutex.new
        end

        # Adds client statistics into internal accumulator. Single statistics set may contain data
        # from multiple topics and their partitions because a single client can operate on multiple
        # topics and partitions. This is why during the `#find` request we locate appropriate data
        # from within of this set of metrics
        #
        # @param consumer_group_id [String] id of the consumer group for which statistics were
        #   emitted.
        # @param statistics [Hash] librdkafka enriched statistics
        def add(consumer_group_id, statistics)
          @mutex.synchronize do
            @accu[consumer_group_id][statistics.fetch('name')] = statistics
          end
        end

        # Finds statistics about requested consumer group topic partition
        #
        # @param topic [Karafka::Routing::Topic]
        # @param partition [Integer]
        # @return [Hash] hash with given topic partition statistics or empty hash if not present
        #
        # @note We do not enclose it with a mutex mainly because the only thing that could happen
        #   here that would be a race-condition is a miss that anyhow we need to support due to
        #   how librdkafka ships metrics.
        def find(topic, partition)
          @accu
            .fetch(topic.consumer_group.id, EMPTY_HASH)
            .each_value do |statistics|
              result = statistics
                       .fetch('topics', EMPTY_HASH)
                       .fetch(topic.name, EMPTY_HASH)
                       .fetch('partitions', EMPTY_HASH)
                       .fetch(partition.to_s, false)

              return result if result
            end

          EMPTY_HASH
        end

        # @param topic [Karafka::Routing::Topic]
        # @param partition [Integer]
        # @return [Boolean] true if statistics of a given topic exist, otherwise false
        def exists?(topic, partition)
          !find(topic, partition).empty?
        end
      end
    end
  end
end

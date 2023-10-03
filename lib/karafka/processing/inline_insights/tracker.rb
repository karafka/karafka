# frozen_string_literal: true

module Karafka
  module Processing
    module InlineInsights
      # Object used to track statistics coming from librdkafka in a way that can be accessible by
      # the consumers
      #
      # We use a single tracker because we do not need state management here as our consumer groups
      # clients identified by statistics name value are unique. On top of that, having a per
      # process one that is a singleton allows us to use tracker easily also from other places like
      # filtering API etc.
      #
      # @note We include cache of 5 minutes for revoked partitions to compensate for cases where
      #   when using LRJ a lost partition data would not be present anymore, however we would still
      #   be in the processing phase. Since those metrics are published with each `poll`, regular
      #   processing is not a subject of this issue. For LRJ we keep the reference. The only case
      #   where this could be switched midway is when LRJ is running for an extended period of time
      #   after the involuntary revocation. Having a time based cache instead of tracking
      #   simplifies the design as we do not have to deal with state tracking, especially since
      #   we would have to track also operations running in a revoked state.
      #
      # @note This tracker keeps in memory data about all topics and partitions that it encounters
      #   because in case of routing patterns, we may start getting statistics prior to registering
      #   given topic via dynamic routing expansions. In such case we would not have insights
      #   where they were actually available for us to use.
      #
      # @note Memory usage is negligible as long as we can evict expired data. Single metrics set
      #   for a single partition contains around 4KB of data. This means, that in case of an
      #   assignment of 1000 partitions, we use around 4MB of space for tracking those metrics.
      class Tracker
        include Singleton
        include Karafka::Core::Helpers::Time

        # Empty hash we want to return in any case where we could not locate appropriate topic
        # partition statistics.
        EMPTY_HASH = {}.freeze

        # Empty array to save on memory allocations.
        EMPTY_ARRAY = [].freeze

        # 5 minutes of cache. We cache last result per consumer group topic partition so we are
        # not affected by involuntary rebalances during LRJ execution.
        TTL = 5 * 60 * 1_000

        private_constant :EMPTY_HASH, :EMPTY_ARRAY, :TTL

        class << self
          extend Forwardable

          def_delegators :instance, :find, :add, :exists?, :clear
        end

        def initialize
          @accu = {}
          @mutex = Mutex.new
        end

        # Adds each partition statistics into internal accumulator. Single statistics set may
        # contain data from multiple topics and their partitions because a single client can
        # operate on multiple topics and partitions.
        #
        # We iterate over those topics and partitions and store topics partitions data only.
        #
        # @param consumer_group_id [String] id of the consumer group for which statistics were
        #   emitted.
        # @param statistics [Hash] librdkafka enriched statistics
        def add(consumer_group_id, statistics)
          @mutex.synchronize do
            statistics.fetch('topics', EMPTY_HASH).each do |topic_name, t_details|
              t_details.fetch('partitions', EMPTY_HASH).each do |partition_id, p_details|
                next unless track?(partition_id, p_details)

                key = "#{consumer_group_id}_#{topic_name}_#{partition_id}"
                @accu[key] = [monotonic_now, p_details]
              end
            end

            evict
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
        #   how librdkafka ships metrics and a potential removal of data on heavily revoked LRJ.
        def find(topic, partition)
          key = "#{topic.consumer_group.id}_#{topic.name}_#{partition}"
          @accu.fetch(key, EMPTY_ARRAY).last || EMPTY_HASH
        end

        # Clears the tracker
        def clear
          @mutex.synchronize { @accu.clear }
        end

        private

        # Evicts expired data from the cache
        def evict
          @accu.delete_if { |_, details| monotonic_now - details.first > TTL }
        end

        # Should we track given partition
        #
        # We do not track stopped partitions and the once we do not work with actively
        # @param partition_id [String] partition id as a string
        # @param p_details [Hash] partition statistics details
        # @return [Boolean] true if we should track given partition
        def track?(partition_id, p_details)
          return false if partition_id == '-1'

          fetch_state = p_details.fetch('fetch_state')

          return false if fetch_state == 'stopped'
          return false if fetch_state == 'none'

          true
        end
      end
    end
  end
end

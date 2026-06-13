# frozen_string_literal: true

module Karafka
  module Connection
    # Partitions pauses management abstraction layer.
    # It aggregates all the pauses for all the partitions that we're working with.
    class PausesManager
      # @return [Karafka::Connection::PausesManager] pauses manager
      def initialize
        @pauses = Hash.new do |h, k|
          h[k] = {}
        end
      end

      # Creates or fetches pause tracker of a given topic partition.
      #
      # @param topic [::Karafka::Routing::Topic] topic
      # @param partition [Integer] partition number
      # @return [Karafka::TimeTrackers::Pause] pause tracker instance
      def fetch(topic, partition)
        @pauses[topic][partition] ||= TimeTrackers::Pause.new(
          timeout: topic.pause_timeout,
          max_timeout: topic.pause_max_timeout,
          exponential_backoff: topic.pause_with_exponential_backoff
        )
      end

      # Resets the attempt count of a given topic partition pause tracker.
      #
      # Used on revocation so that a later reclaim of the same partition starts counting retry
      # attempts from zero instead of carrying the stale count across the rebalance. We reset
      # rather than remove the tracker because the pause itself may still need to be resumed after
      # the reclaim (the partition can be re-paused via the retained paused offsets on rebalance).
      #
      # @param topic [::Karafka::Routing::Topic] topic
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        return unless @pauses.key?(topic)

        @pauses[topic][partition]&.reset
      end

      # Resumes processing of partitions for which pause time has ended.
      #
      # @yieldparam [Karafka::Routing::Topic] topic
      # @yieldparam [Integer] partition number
      def resume
        @pauses.each do |topic, partitions|
          partitions.each do |partition, pause|
            next unless pause.paused?
            next unless pause.expired?

            pause.resume

            yield(topic, partition)
          end
        end
      end
    end
  end
end

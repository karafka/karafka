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
          timeout: topic.pause.timeout,
          max_timeout: topic.pause.max_timeout,
          exponential_backoff: topic.pause.with_exponential_backoff
        )
      end

      # Resets the attempt count of a given topic partition pause tracker, or removes it entirely
      # if it is not currently paused.
      #
      # Used on revocation so that a later reclaim of the same partition starts counting retry
      # attempts from zero instead of carrying the stale count across the rebalance. We reset
      # rather than remove a tracker that is currently paused because the pause itself may still
      # need to be resumed after the reclaim (the partition can be re-paused via the retained
      # paused offsets on rebalance) - this matters under eager rebalancing, where every
      # previously owned partition is revoked and then reassigned even when nothing has actually
      # changed for it. A tracker that is not paused has no state worth preserving, so we remove
      # it instead via `#delete` - this is what actually bounds `@pauses`, since otherwise entries
      # accumulate forever for topics whose routing `Topic` object is never reused across
      # reassignment (e.g. regex pattern subscriptions with ephemeral, per-discovery topic names).
      #
      # A coordinator and its pause tracker are created together in
      # `CoordinatorsBuffer#find_or_create`, and `CoordinatorsBuffer#revoke` only calls us once it
      # has confirmed the coordinator exists - so the tracker is always present here.
      #
      # @param topic [::Karafka::Routing::Topic] topic
      # @param partition [Integer] partition number
      def revoke(topic, partition)
        pause = @pauses[topic][partition]

        return delete(topic, partition) unless pause.paused?

        pause.reset
      end

      # Removes the pause tracker of a given topic partition, dropping the topic entry entirely
      # once it no longer tracks any partitions.
      #
      # @param topic [::Karafka::Routing::Topic] topic
      # @param partition [Integer] partition number
      def delete(topic, partition)
        partitions = @pauses[topic]
        partitions.delete(partition)

        @pauses.delete(topic) if partitions.empty?
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

# frozen_string_literal: true

module Karafka
  module TimeTrackers
    # Tracker used to keep time reference when we last time dispatched any job related to a given
    # topic partition.
    #
    # We can use it to know when last time a job was scheduled
    #
    # @note We do not track revocation as on revocation we clear given topic partition reference
    #   not to have a potential memory leak
    #
    # @note We do not track shutdown jobs as shutdown is finishing the process, so no time
    #   sensitive operations remain that would use this
    #
    # @note We consider partition as active if we scheduled any job related to it within the tick
    #   interval. This has nothing to do whether a partition is assigned.
    class PartitionUsage < Base
      # Creates new partition usage time tracker
      def initialize
        super

        @last_usage = Hash.new do |topics_hash, topic_name|
          topics_hash[topic_name] = Hash.new do |partitions_hash, partition_id|
            partitions_hash[partition_id] = 0
          end
        end
      end

      # @param topic [String]
      # @param partition [Integer]
      # @param interval [Integer] minimum interval
      # @return [Boolean] was this topic partition active
      def active?(topic, partition, interval)
        monotonic_now - @last_usage[topic][partition] < interval
      end

      # Marks usage of given partition
      #
      # @param topic [String]
      # @param partition [Integer]
      def track(topic, partition)
        @last_usage[topic][partition] = monotonic_now
      end

      # Clears references about given partition. Useful on revocation so we do not store old
      # unassigned partitions data
      #
      # @param topic [String]
      # @param partition [Integer]
      def revoke(topic, partition)
        @last_usage[topic].delete(partition)
      end
    end
  end
end

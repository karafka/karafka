# frozen_string_literal: true

module Karafka
  module Connection
    module ConsumerGroups
      # Tracks the last offset handed over per partition, to detect messages that went back in
      # offsets without a seek, e.g. after an offset reset of a recreated topic. It matters only
      # because a drain moves the librdkafka position forward and never back: after such a step
      # back the position stays ahead of what we handed over, and a pause without an offset or a
      # skipped seek would then lose messages. See `Client#seek_after_drain`
      #
      # @note Messages come in runs of one partition, so the last offset of a partition is stored
      #   only when the partition changes, and a message of the same partition is compared with
      #   the previous one. Only the coordinates of the previous message are kept, not the message,
      #   so its payload is not retained between batches
      class OffsetRegressionTracker
        # @return [Karafka::Connection::ConsumerGroups::OffsetRegressionTracker] tracker without
        #   any tracked offsets
        def initialize
          @last_offsets = Hash.new { |hash, topic_name| hash[topic_name] = {} }
          @previous_topic = nil
          @previous_partition = nil
          @previous_offset = nil
          @rewound = nil
        end

        # Records the message as the last one handed over for its partition and flags its partition
        # as rewound when its offset is lower than the one of the previous message of its partition
        #
        # @param message [Rdkafka::Consumer::Message] message handed over to the buffer
        def track(message)
          topic_name = message.topic
          partition = message.partition
          offset = message.offset

          if @previous_partition == partition && @previous_topic == topic_name
            rewind(topic_name, partition) if offset < @previous_offset
          else
            @last_offsets[@previous_topic][@previous_partition] = @previous_offset if @previous_topic
            last_offset = @last_offsets[topic_name][partition]
            rewind(topic_name, partition) if last_offset && offset < last_offset
            @previous_topic = topic_name
            @previous_partition = partition
          end

          @previous_offset = offset
        end

        # Stores the message as the last one handed over for its partition, without checking it.
        # A blocking poll always moves the position to its message, so it cannot leave it stale
        #
        # @param message [Rdkafka::Consumer::Message] message handed over to the buffer
        def store(message)
          @last_offsets[@previous_topic][@previous_partition] = @previous_offset if @previous_topic
          @previous_topic = message.topic
          @previous_partition = message.partition
          @previous_offset = message.offset
        end

        # @return [Hash{String => Array<Integer>}, nil] partitions per topic with messages tracked
        #   behind the previous message of their partition since the last call, nil when none
        def rewound
          rewound = @rewound
          @rewound = nil
          rewound
        end

        # Removes the last offsets of revoked partitions, so messages of a partition assigned back
        # later are not compared with offsets from before the revocation. Rewound partitions not
        # taken yet are dropped, as they are from before the rebalance
        #
        # @param revoked_partitions [Hash{String => Array<Integer>}] revoked partitions per topic
        def forget(revoked_partitions)
          @rewound = nil

          revoked_partitions.each do |topic_name, partitions|
            clear_previous if @previous_topic == topic_name && partitions.include?(@previous_partition)

            next unless @last_offsets.key?(topic_name)

            partitions.each { |partition| @last_offsets[topic_name].delete(partition) }
          end
        end

        # Removes all the tracked offsets
        def clear
          @last_offsets.clear
          clear_previous
          @rewound = nil
        end

        private

        # Flags the partition as rewound
        #
        # @param topic_name [String]
        # @param partition [Integer]
        def rewind(topic_name, partition)
          partitions = ((@rewound ||= {})[topic_name] ||= [])
          partitions << partition unless partitions.include?(partition)
        end

        # Forgets the previous message coordinates
        def clear_previous
          @previous_topic = nil
          @previous_partition = nil
          @previous_offset = nil
        end
      end
    end
  end
end

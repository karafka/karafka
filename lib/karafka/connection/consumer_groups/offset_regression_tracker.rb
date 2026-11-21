# frozen_string_literal: true

module Karafka
  module Connection
    module ConsumerGroups
      # Tracks the last offset handed over per partition, to detect messages that went back in
      # offsets without a seek, e.g. after an offset reset of a recreated topic
      #
      # @note Messages come in runs of one partition, so the last offset of a partition is stored
      #   only when the partition changes, and a message of the same partition is compared with
      #   the previous one
      class OffsetRegressionTracker
        # @return [Karafka::Connection::ConsumerGroups::OffsetRegressionTracker] tracker without
        #   any tracked offsets
        def initialize
          @last_offsets = Hash.new { |hash, topic_name| hash[topic_name] = {} }
          @previous = nil
          @rewound = nil
        end

        # Records the message as the last one handed over for its partition and flags it as
        # rewound when its offset is lower than the one of the previous message of its partition
        #
        # @param message [Rdkafka::Consumer::Message] message handed over to the buffer
        def track(message)
          previous = @previous

          if previous && previous.partition == message.partition && previous.topic == message.topic
            (@rewound ||= []) << message if message.offset < previous.offset
          else
            @last_offsets[previous.topic][previous.partition] = previous.offset if previous
            last_offset = @last_offsets[message.topic][message.partition]
            (@rewound ||= []) << message if last_offset && message.offset < last_offset
          end

          @previous = message
        end

        # Stores the message as the last one handed over for its partition, without checking it.
        # A blocking poll always moves the position to its message, so it cannot leave it stale
        #
        # @param message [Rdkafka::Consumer::Message] message handed over to the buffer
        def store(message)
          previous = @previous
          @last_offsets[previous.topic][previous.partition] = previous.offset if previous
          @previous = message
        end

        # @return [Array<Rdkafka::Consumer::Message>, nil] messages tracked behind the previous
        #   message of their partition since the last call, nil when there were none
        def rewound
          rewound = @rewound
          @rewound = nil
          rewound
        end

        # Removes the last offsets of revoked partitions, so messages of a partition assigned back
        # later are not compared with offsets from before the revocation. Rewound messages not
        # taken yet are dropped, as they are from before the rebalance
        #
        # @param revoked_partitions [Hash{String => Array<Integer>}] revoked partitions per topic
        def forget(revoked_partitions)
          @rewound = nil

          revoked_partitions.each do |topic_name, partitions|
            if @previous&.topic == topic_name && partitions.include?(@previous.partition)
              @previous = nil
            end

            next unless @last_offsets.key?(topic_name)

            partitions.each { |partition| @last_offsets[topic_name].delete(partition) }
          end
        end

        # Removes all the tracked offsets
        def clear
          @last_offsets.clear
          @previous = nil
          @rewound = nil
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Connection
    module ConsumerGroups
      # Decides which partitions need a seek after a drain and where to. It does not seek and does
      # not check positions: the client does both under its mutex
      #
      # @note Rewinds are planned before the drained messages of revoked partitions are removed
      #   from the buffer and alignments after it, because the removal also drops duplicates that
      #   can change the last drained message of a partition
      class DrainSeekPlanner
        # Default for partitions lookups without allocations
        EMPTY_ARRAY = [].freeze

        private_constant :EMPTY_ARRAY

        # A partition can be revoked and assigned back within one drain and librdkafka may then
        # already be past some of its drained messages, which are removed with the revoked ones.
        # Such partitions go back to the lowest of their drained offsets. A drained message from
        # before the revocation can precede lower ones, so the lowest is used and the client never
        # seeks forward
        #
        # @param buffer [Karafka::Connection::RawMessagesBuffer] buffer after the drain
        # @param revoked [Hash{String => Array<Integer>}] partitions revoked per topic
        # @param assigned [Hash{String => Array<Integer>}] partitions assigned per topic
        # @return [Array<Karafka::Messages::Seek>] seeks to the lowest drained offsets
        def rewinds(buffer, revoked, assigned)
          rewinds = []

          buffer.each do |topic_name, partition, messages|
            next if messages.empty?
            next unless revoked.fetch(topic_name, EMPTY_ARRAY).include?(partition)
            next unless assigned.fetch(topic_name, EMPTY_ARRAY).include?(partition)

            rewinds << Messages::Seek.new(topic_name, partition, messages.map(&:offset).min)
          end

          rewinds
        end

        # A blocking poll always moves the position of a partition to its message, but the drain
        # moves it only forward. When the offsets went back without a seek, e.g. on an offset
        # reset after the topic was recreated, the position stays ahead of the drained messages
        # and a pause without an offset would resume from it. Such partitions go to right after
        # their last drained message. When it is followed by a transaction marker, the position is
        # rightly past it, so the seek purges the prefetched messages once. It does not lose any
        #
        # @param buffer [Karafka::Connection::RawMessagesBuffer] buffer after the revoked
        #   partitions were removed from it
        # @param rewound [Hash{String => Array<Integer>}] partitions per topic whose drained
        #   offsets went back
        # @return [Array<Karafka::Messages::Seek>] seeks to right after the last drained messages
        def alignments(buffer, rewound)
          alignments = []

          buffer.each do |topic_name, partition, messages|
            next if messages.empty?
            next unless rewound.fetch(topic_name, EMPTY_ARRAY).include?(partition)

            alignments << Messages::Seek.new(topic_name, partition, messages.last.offset + 1)
          end

          alignments
        end
      end
    end
  end
end

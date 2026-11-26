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

        # Plans seeks back to the lowest drained offset of partitions revoked and assigned back
        # within the drain. See `Client#seek_after_drain`
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

        # Plans seeks to right after the last drained message of partitions whose drained offsets
        # went back. See `Client#seek_after_drain`
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

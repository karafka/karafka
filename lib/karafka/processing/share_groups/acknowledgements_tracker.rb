# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Tracks which records of its current batch a share consumer already acknowledged.
      #
      # Every record has to be acknowledged exactly once: librdkafka refuses to poll again until
      # each record of the previous poll is acknowledged, and acknowledging the same record twice
      # corrupts its accounting. Consumers use this tracker to acknowledge each record only once
      # and to settle, after the consumption, only the records that were not acknowledged.
      #
      # @note Users may acknowledge from their own threads within `#consume`, hence the mutex.
      class AcknowledgementsTracker
        def initialize
          @acknowledged = Set.new
          @mutex = Mutex.new
        end

        # Marks the record as acknowledged unless it already was
        #
        # @param message [Karafka::Messages::Message] record
        # @return [Boolean] true if the record was not acknowledged before, false otherwise
        def acknowledge(message)
          @mutex.synchronize { !@acknowledged.add?(key(message)).nil? }
        end

        # @param message [Karafka::Messages::Message] record
        # @return [Boolean] was this record already acknowledged
        def acknowledged?(message)
          @mutex.synchronize { @acknowledged.include?(key(message)) }
        end

        # Forgets the acknowledgements, used when a new batch is about to be consumed
        def clear
          @mutex.synchronize { @acknowledged.clear }
        end

        private

        # @param message [Karafka::Messages::Message] record
        # @return [Array] key identifying the record within the share group
        def key(message)
          [message.topic, message.partition, message.offset]
        end
      end
    end
  end
end

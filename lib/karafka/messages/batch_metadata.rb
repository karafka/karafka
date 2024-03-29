# frozen_string_literal: true

module Karafka
  module Messages
    # Simple batch metadata object that stores all non-message information received from Kafka
    # cluster while fetching the data.
    #
    # @note This metadata object refers to per batch metadata, not `#message.metadata`
    BatchMetadata = Struct.new(
      :size,
      :first_offset,
      :last_offset,
      :deserializers,
      :partition,
      :topic,
      :created_at,
      :scheduled_at,
      :processed_at,
      keyword_init: true
    ) do
      # This lag describes how long did it take for a message to be consumed from the moment it was
      # created
      #
      #
      # @return [Integer] number of milliseconds
      # @note In case of usage in workless flows, this value will be set to -1
      def consumption_lag
        processed_at ? time_distance_in_ms(processed_at, created_at) : -1
      end

      # This lag describes how long did a batch have to wait before it was picked up by one of the
      # workers
      #
      # @return [Integer] number of milliseconds
      # @note In case of usage in workless flows, this value will be set to -1
      def processing_lag
        processed_at ? time_distance_in_ms(processed_at, scheduled_at) : -1
      end

      private

      # Computes time distance in between two times in ms
      #
      # @param time1 [Time]
      # @param time2 [Time]
      # @return [Integer] distance in between two times in ms
      def time_distance_in_ms(time1, time2)
        ((time1 - time2) * 1_000).round
      end
    end
  end
end

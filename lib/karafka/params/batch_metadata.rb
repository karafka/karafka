# frozen_string_literal: true

module Karafka
  module Params
    # Simple batch metadata object that stores all non-message information received from Kafka
    # cluster while fetching the data
    # @note This metadata object refers to per batch metadata, not `#params.metadata`
    BatchMetadata = Struct.new(
      :batch_size,
      :first_offset,
      :highwater_mark_offset,
      :unknown_last_offset,
      :last_offset,
      :offset_lag,
      :deserializer,
      :partition,
      :topic,
      keyword_init: true
    ) do
      # @return [Boolean] is the last offset known or unknown
      def unknown_last_offset?
        unknown_last_offset
      end
    end
  end
end

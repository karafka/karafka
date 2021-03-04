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
      :deserializer,
      :partition,
      :topic,
      :scheduled_at,
      keyword_init: true
    )
  end
end

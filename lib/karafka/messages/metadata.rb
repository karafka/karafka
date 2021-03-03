# frozen_string_literal: true

module Karafka
  module Messages
    # Single message metadata details that can be accessed without the need of deserialization.
    Metadata = Struct.new(
      :timestamp,
      :headers,
      :key,
      :offset,
      :deserializer,
      :partition,
      :received_at,
      :topic,
      keyword_init: true
    )
  end
end

# frozen_string_literal: true

module Karafka
  module Params
    # Single message / params metadata details that can be accessed without the need for the
    # payload deserialization
    Metadata = Struct.new(
      :create_time,
      :headers,
      :is_control_record,
      :key,
      :offset,
      :deserializer,
      :partition,
      :receive_time,
      :topic,
      keyword_init: true
    )
  end
end

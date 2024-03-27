# frozen_string_literal: true

module Karafka
  module Messages
    # Single message metadata details that can be accessed without the need of deserialization.
    Metadata = Struct.new(
      :message,
      :timestamp,
      :offset,
      :deserializers,
      :partition,
      :received_at,
      :topic,
      :raw_headers,
      :raw_key,
      keyword_init: true
    ) do
      # @return [Object] deserialized key. By default in the raw string format.
      def key
        return @key if @key

        @key = deserializers.key.call(self)
      end

      # @return [Object] deserialized headers. By default its a hash with keys and payload being
      #   strings
      def headers
        return @headers if @headers

        @headers = deserializers.headers.call(self)
      end
    end
  end
end

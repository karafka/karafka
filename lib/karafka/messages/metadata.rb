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
      # @note The result is cached after the first deserialization, including `nil` and other
      #   falsy results (e.g. keyless messages), hence the explicit flag instead of a
      #   truthiness check. As with `Message#payload`, the flag is set only after a successful
      #   deserialization, so an error is not cached and the next access retries.
      def key
        return @key if @key_deserialized

        @key = deserializers.key.call(self)
        @key_deserialized = true
        @key
      end

      # @return [Object] deserialized headers. By default its a hash with keys and payload being
      #   strings
      # @note Caching works as in {#key}, including falsy results
      def headers
        return @headers if @headers_deserialized

        @headers = deserializers.headers.call(self)
        @headers_deserialized = true
        @headers
      end
    end
  end
end

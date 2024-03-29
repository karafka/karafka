# frozen_string_literal: true

module Karafka
  # Module for all supported by default deserializers.
  module Deserializers
    # Default Karafka Json deserializer for loading JSON data in payload.
    class Payload
      # @param message [Karafka::Messages::Message] Message object that we want to deserialize
      # @return [Hash] hash with deserialized JSON data
      def call(message)
        # nil payload can be present for example for tombstone messages
        message.raw_payload.nil? ? nil : ::JSON.parse(message.raw_payload)
      end
    end
  end
end

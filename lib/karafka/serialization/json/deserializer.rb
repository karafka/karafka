# frozen_string_literal: true

module Karafka
  # Module for all supported by default serialization and deserialization ways.
  module Serialization
    # Namespace for json serializers and deserializers.
    module Json
      # Default Karafka Json deserializer for loading JSON data.
      class Deserializer
        # @param message [Karafka::Messages::Message] Message object that we want to deserialize
        # @return [Hash] hash with deserialized JSON data
        def call(message)
          message.raw_payload.nil? ? nil : ::JSON.parse(message.raw_payload)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Module for all supported by default serialization and deserialization ways
  module Serialization
    # Namespace for json ser/der
    module Json
      # Default Karafka Json deserializer for loading JSON data
      class Deserializer
        # @param params [Karafka::Params::Params] Full params object that we want to deserialize
        # @return [Hash] hash with deserialized JSON data
        # @example
        #   params = {
        #     'payload' => "{\"a\":1}",
        #     'topic' => 'my-topic',
        #     'headers' => { 'message_type' => :test }
        #   }
        #   Deserializer.call(params) #=> { 'a' => 1 }
        def call(params)
          ::MultiJson.load(params['payload'])
        rescue ::MultiJson::ParseError => e
          raise ::Karafka::Errors::DeserializationError, e
        end
      end
    end
  end
end

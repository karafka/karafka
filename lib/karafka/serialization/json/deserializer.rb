# frozen_string_literal: true

module Karafka
  # Module for all supported by default serialization and deserialization ways
  module Serialization
    # Namespace for json ser/der
    module Json
      # Default Karafka Json deserializer for loading JSON data
      class Deserializer
        # @param content [String] content based on which we want to get our hash
        # @return [Hash] hash with deserialized JSON data
        # @example
        #   Deserializer.call("{\"a\":1}") #=> { 'a' => 1 }
        def call(content)
          ::MultiJson.load(content)
        rescue ::MultiJson::ParseError => e
          raise ::Karafka::Errors::DeserializationError, e
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Module for all supported by default serialization and deserialization ways
  module Serialization
    module Json
      # Default Karafka Json serializer for serializing data
      class Serializer
        # @param content [Object] any object that we want to convert to a json string
        # @return [String] Valid JSON string containing serialized data
        # @raise [Karafka::Errors::SerializationError] raised when we don't have a way to
        #   serialize provided data to json
        # @note When string is passed to this method, we assume that it is already a json
        #   string and we don't serialize it again. This allows us to serialize data before
        #   it is being forwarded to this serializer if we want to have a custom (not that simple)
        #   json serialization
        #
        # @example From an ActiveRecord object
        #   Serializer.call(Repository.first) #=> "{\"repository\":{\"id\":\"04b504e0\"}}"
        # @example From a string (no changes)
        #   Serializer.call("{\"a\":1}") #=> "{\"a\":1}"
        def call(content)
          return content if content.is_a?(String)
          return content.to_json if content.respond_to?(:to_json)

          raise Karafka::Errors::SerializationError, content
        end
      end
    end
  end
end

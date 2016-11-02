module Karafka
  # Module for all supported by default parsers for incoming/outgoing data
  module Parsers
    # Default Karafka Json parser for serializing and deserializing data
    class Json
      # @param content [String] content based on which we want to get our hash
      # @return [Hash] hash with parsed JSON data
      # @example
      #   Json.parse("{\"a\":1}") #=> { 'a' => 1 }
      def self.parse(content)
        ::JSON.parse(content)
      rescue ::JSON::ParserError => e
        raise ::Karafka::Errors::ParserError, e
      end

      # @param content [Object] any object that we want to convert to a json string
      # @return [String] Valid JSON string containing serialized data
      # @raise [Karafka::Errors::ParserError] raised when we don't have a way to parse
      #   given content to a json string format
      # @note When string is passed to this method, we assume that it is already a json
      #   string and we don't serialize it again. This allows us to serialize data before
      #   it is being forwarded to a parser if we want to have a custom (not that simple)
      #   json serialization
      #
      # @example From an ActiveRecord object
      #   Json.generate(Repository.first) #=> "{\"repository\":{\"id\":\"04b504e0\"}}"
      # @example From a string (no changes)
      #   Json.generate("{\"a\":1}") #=> "{\"a\":1}"
      def self.generate(content)
        return content if content.is_a?(String)
        return content.to_json if content.respond_to?(:to_json)
        raise Karafka::Errors::ParserError, content
      end
    end
  end
end

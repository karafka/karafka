# frozen_string_literal: true

module Karafka
  # Messages namespace encapsulating all the logic that is directly related to messages handling
  module Messages
    # It provides lazy loading not only until the first usage, but also allows us to skip
    # using deserializer until we execute our logic. That way we can operate with
    # heavy-deserialization data without slowing down the whole application.
    class Message
      extend Forwardable
      extend Helpers::ConfigImporter.new(
        parser: %i[internal messages parser]
      )

      attr_reader :metadata
      # raw payload needs to be mutable as we want to have option to change it in the parser
      # prior to the final deserialization
      attr_accessor :raw_payload

      # We remove message as we do not want to do self-reference via `message.message`
      def_delegators :metadata, *((Metadata.members + %i[key headers]) - %i[message])

      # @param raw_payload [Object] incoming payload before deserialization
      # @param metadata [Karafka::Messages::Metadata] message metadata object
      def initialize(raw_payload, metadata)
        @raw_payload = raw_payload
        @metadata = metadata
        @deserialized = false
        @payload = nil
      end

      # @return [Object] lazy-deserialized data (deserialized upon first request)
      def payload
        return @payload if deserialized?

        @payload = deserialize
        # We mark deserialization as successful after deserialization, as in case of an error
        # this won't be falsely set to true
        @deserialized = true
        @payload
      end

      # @return [Boolean] did we deserialize payload already
      def deserialized?
        @deserialized
      end

      # @return [Boolean] true if the message has a key and raw payload is nil, it is a tombstone
      #   event. Otherwise it is not.
      def tombstone?
        !raw_key.nil? && @raw_payload.nil?
      end

      private

      # @return [Object] deserialized data
      def deserialize
        self.class.parser.call(self)
      end
    end
  end
end

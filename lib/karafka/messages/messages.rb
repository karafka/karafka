# frozen_string_literal: true

module Karafka
  module Messages
    # Messages batch represents a set of messages received from Kafka of a single topic partition.
    class Messages
      include Enumerable

      attr_reader :metadata

      # @param messages_array [Array<Karafka::Messages::Message>] array with karafka messages
      # @param metadata [Karafka::Messages::BatchMetadata]
      # @return [Karafka::Messages::Messages] lazy evaluated messages batch object
      def initialize(messages_array, metadata)
        @messages_array = messages_array
        @metadata = metadata
      end

      # @param block [Proc] block we want to execute per each message
      # @note Invocation of this method will not cause loading and deserializing of messages.
      def each(&block)
        @messages_array.each(&block)
      end

      # Runs deserialization of all the messages and returns them
      # @return [Array<Karafka::Messages::Message>]
      def deserialize!
        each(&:payload)
      end

      # @return [Array<Object>] array with deserialized payloads. This method can be useful when
      #   we don't care about metadata and just want to extract all the data payloads from the
      #   batch
      def payloads
        map(&:payload)
      end

      # @return [Array<String>] array with raw, not deserialized payloads
      def raw_payloads
        map(&:raw_payload)
      end

      # @return [Boolean] is the messages batch empty
      def empty?
        @messages_array.empty?
      end

      # @return [Karafka::Messages::Message] first message
      def first
        @messages_array.first
      end

      # @return [Karafka::Messages::Message] last message
      def last
        @messages_array.last
      end

      # @return [Integer] number of messages in the batch
      def size
        @messages_array.size
      end

      # @return [Array<Karafka::Messages::Message>] copy of the pure array with messages
      def to_a
        @messages_array.dup
      end

      alias count size
    end
  end
end

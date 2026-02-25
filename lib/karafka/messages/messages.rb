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

      # @note Invocation of this method will not cause loading and deserializing of messages.
      def each(&)
        @messages_array.each(&)
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

      # Returns the underlying messages array directly without duplication.
      #
      # This method exists to provide Karafka internals with direct access to the messages array,
      # bypassing any monkey patches that external libraries may apply to enumerable methods.
      #
      # ## Why this method exists
      #
      # External instrumentation libraries like DataDog's `dd-trace-rb` patch the `#each` method
      # on this class to create tracing spans around message iteration. While this is desirable
      # for user code (to trace message processing), it causes problems when Karafka's internal
      # infrastructure iterates over messages for housekeeping tasks (offset tracking,
      # deserialization, etc.) - creating empty/unwanted spans.
      #
      # By using `raw.map` or `raw.each` instead of `map` or `each` directly, internal code
      # bypasses the patched `#each` method since it operates on the raw Array, not this class.
      #
      # ## Usage
      #
      # This method should ONLY be used by Karafka internals. User-facing code (consumers,
      # ActiveJob processors, etc.) should use regular `#each`/`#map` so that instrumentation
      # libraries can properly trace message processing.
      #
      # @return [Array<Karafka::Messages::Message>] the underlying messages array (not a copy)
      #
      # @note This returns the actual internal array, not a copy. Do not modify it.
      # @see https://github.com/karafka/karafka/issues/2939
      #
      # @private
      def raw
        @messages_array
      end

      alias_method :count, :size
    end
  end
end

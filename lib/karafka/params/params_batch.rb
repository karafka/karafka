# frozen_string_literal: true

module Karafka
  module Params
    # Params batch represents a set of messages received from Kafka.
    # @note Params internally are lazy loaded before first use. That way we can skip
    #   deserialization process if we have after_fetch that rejects some incoming messages
    #   without using params It can be also used when handling really heavy data.
    class ParamsBatch
      include Enumerable

      # @param params_array [Array<Karafka::Params::Params>] array with karafka params
      # @return [Karafka::Params::ParamsBatch] lazy evaluated params batch object
      def initialize(params_array)
        @params_array = params_array
      end

      # @yieldparam [Karafka::Params::Params] each deserialized and loaded params instance
      # @note Invocation of this method will cause loading and deserializing each param after
      #   another. If you want to get access without deserializing, please access params_array
      #   directly
      def each
        @params_array.each { |param| yield(param.deserialize!) }
      end

      # @return [Array<Karafka::Params::Params>] returns all the params in a loaded state, so they
      #   can be used for batch insert, etc. Without invoking all, up until first use, they won't
      #   be deserialized
      def deserialize!
        each(&:itself)
      end

      # @return [Array<Object>] array with deserialized payloads. This method can be useful when
      #   we don't care about metadata and just want to extract all the data payloads from the
      #   batch
      def payloads
        deserialize!.map(&:payload)
      end

      # @return [Karafka::Params::Params] first element after the deserialization process
      def first
        @params_array.first.deserialize!
      end

      # @return [Karafka::Params::Params] last element after the deserialization process
      def last
        @params_array.last.deserialize!
      end

      # @return [Array<Karafka::Params::Params>] pure array with params (not deserialized)
      def to_a
        @params_array
      end

      # @return [Integer] number of messages in the batch
      def size
        @params_array.size
      end
    end
  end
end

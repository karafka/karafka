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

      # @yieldparam [Karafka::Params::Params] each params instance
      # @note Invocation of this method will not cause loading and deserializing each param after
      #   another.
      def each
        @params_array.each { |param| yield(param) }
      end

      # @return [Array<Karafka::Params::Params>] returns all the params in a loaded state, so they
      #   can be used for batch insert, etc. Without invoking all, up until first use, they won't
      #   be deserialized
      def deserialize!
        each(&:payload)
      end

      # @return [Array<Object>] array with deserialized payloads. This method can be useful when
      #   we don't care about metadata and just want to extract all the data payloads from the
      #   batch
      def payloads
        map(&:payload)
      end

      # @return [Karafka::Params::Params] first element
      def first
        @params_array.first
      end

      # @return [Karafka::Params::Params] last element
      def last
        @params_array.last
      end

      # @return [Integer] number of messages in the batch
      def size
        @params_array.size
      end

      # @return [Array<Karafka::Params::Params>] pure array with params
      def to_a
        @params_array
      end
    end
  end
end

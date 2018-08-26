# frozen_string_literal: true

module Karafka
  module Params
    # Params batch represents a set of messages received from Kafka.
    # @note Params internally are lazy loaded before first use. That way we can skip parsing
    #   process if we have after_fetch that rejects some incoming messages without using params
    #   It can be also used when handling really heavy data (in terms of parsing).
    class ParamsBatch
      include Enumerable

      # @param params_array [Array<Karafka::Params::Params>] array with karafka params
      # @return [Karafka::Params::ParamsBatch] lazy evaluated params batch object
      def initialize(params_array)
        @params_array = params_array
      end

      # @yieldparam [Karafka::Params::Params] each parsed and loaded params instance
      # @note Invocation of this method will cause loading and parsing each param after another.
      #   If you want to get access without parsing, please access params_array directly
      def each
        @params_array.each { |param| yield(param.parse!) }
      end

      # @return [Array<Karafka::Params::Params>] returns all the params in a loaded state, so they
      #   can be used for batch insert, etc. Without invoking all, up until first use, they won't
      #   be parsed
      def parse!
        each(&:itself)
      end

      # @return [Array<Object>] array with parsed values. This method can be useful when we don't
      #   care about metadata and just want to extract all the data values from the batch
      def values
        parse!.map(&:value)
      end

      # @return [Karafka::Params::Params] first element after the parsing process
      def first
        @params_array.first.parse!
      end

      # @return [Karafka::Params::Params] last element after the parsing process
      def last
        @params_array.last.parse!
      end

      # @return [Array<Karafka::Params::Params>] pure array with params (not parsed)
      def to_a
        @params_array
      end
    end
  end
end

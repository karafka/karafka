# frozen_string_literal: true

module Karafka
  module Params
    # Params batch represents a set of messages received from Kafka.
    # @note Params internally are lazy loaded before first use. That way we can skip parsing
    #   process if we have after_fetch that rejects some incoming messages without using params
    #   It can be also used when handling really heavy data (in terms of parsing).
    class ParamsBatch
      include Enumerable

      # Builds up a params batch based on raw kafka messages
      # @param messages_batch [Array<Kafka::FetchedMessage>] messages batch
      # @param topic [(Karafka::Routing::Topic] topic for which we received this batch
      def initialize(messages_batch, topic)
        @params_batch = messages_batch.map! do |message|
          Karafka::Params::Params.build(message, topic)
        end
      end

      # @yieldparam [Karafka::Params::Params] each parsed and loaded params instance
      # @note Invocation of this method will cause loading and parsing each param after another.
      #   If you want to get access without parsing, please access params_batch directly
      def each
        @params_batch.each { |param| yield(param.parse!) }
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
        @params_batch.first.parse!
      end

      # @return [Karafka::Params::Params] last element after the parsing process
      def last
        @params_batch.last.parse!
      end

      # @return [Array<Karafka::Params::Params>] pure array with params (not parsed)
      def to_a
        @params_batch
      end
    end
  end
end

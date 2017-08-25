# frozen_string_literal: true

module Karafka
  module Params
    # Params batch represents a set of messages received from Kafka.
    # @note Params internally are lazy loaded before first use. That way we can skip parsing
    #   process if we have after_received that rejects some incoming messages without using params
    #   It can be also used when handling really heavy data (in terms of parsing). Without direct
    #   usage outside of worker scope, it will pass raw data into sidekiq, so we won't use Karafka
    #   working time to parse this data. It will happen only in the worker (where it can take time)
    #   that way Karafka will be able to process data really quickly. On the other hand, if we
    #   decide to use params somewhere before it hits worker logic, it won't parse it again in
    #   the worker - it will use already loaded data and pass it to Redis
    class ParamsBatch
      include Enumerable

      # Builds up a params batch based on raw kafka messages
      # @param messages_batch [Array<Kafka::FetchedMessage>] messages batch
      # @param topic_parser [Class] topic parser for unparsing messages values
      def initialize(messages_batch, topic_parser)
        @params_batch = messages_batch.map do |message|
          Karafka::Params::Params.build(message, topic_parser)
        end
      end

      # @yieldparam [Karafka::Params::Params] each parsed and loaded params instance
      # @note Invocation of this method will cause loading and parsing each param after another.
      #   If you want to get access without parsing, please access params_batch directly
      def each
        @params_batch.each { |param| yield(param.retrieve) }
      end

      # @return [Array<Karafka::Params::Params>] returns all the params in a loaded state, so they
      #   can be used for batch insert, etc. Without invoking all, up until first use, they won't
      #   be parsed
      def parsed
        each(&:itself)
      end

      # @return [Array<Karafka::Params::Params>] pure array with params (not parsed)
      def to_a
        @params_batch
      end
    end
  end
end

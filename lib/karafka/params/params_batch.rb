# frozen_string_literal: true

module Karafka
  module Params
    # Params batch represents a set of messages received from Kafka
    class ParamsBatch
      include Enumerable

      def initialize(messages_set, topic_parser)
        @collection = messages_set.map do |message|
          Karafka::Params::Params.build(message, topic_parser)
        end
      end

      # @return [Karafka::Params::Params] Karafka params that is a hash with indifferent access
      # @note Params internally are lazy loaded before first use. That way we can skip parsing
      #   process if we have before_enqueue that rejects some incoming messages without using params
      #   It can be also used when handling really heavy data (in terms of parsing). Without direct
      #   usage outside of worker scope, it will pass raw data into sidekiq, so we won't use Karafka
      #   working time to parse this data. It will happen only in the worker (where it can take time)
      #   that way Karafka will be able to process data really quickly. On the other hand, if we
      #   decide to use params somewhere before it hits worker logic, it won't parse it again in
      #   the worker - it will use already loaded data and pass it to Redis
      # @note Invokation of this method will cause load all the data into params object. If you want
      #   to get access without parsing, please access @params directly
      def each(&block)

        @collection.each { |param| block.call(param.retrieve) }
      end

      def to_a
        @collection
      end
    end
  end
end

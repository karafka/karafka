# frozen_string_literal: true

module Karafka
  module Processing
    # Basic partitioner for work division
    # It does not divide any work.
    class Partitioner
      def initialize(subscription_group)
        @subscription_group = subscription_group
      end

      # @param topic [String] topic name
      # @param messages [Array<Karafka::Messages::Message>] karafka messages
      # @yieldparam [Integer] group id
      # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
      def call(topic, messages)
        yield(0, messages)
      end
    end
  end
end

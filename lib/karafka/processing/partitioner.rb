# frozen_string_literal: true

module Karafka
  module Processing
    # Basic partitioner for work division
    # It does not divide any work.
    class Partitioner
      # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group
      def initialize(subscription_group)
        @subscription_group = subscription_group
      end

      # @param _topic [String] topic name
      # @param messages [Array<Karafka::Messages::Message>] karafka messages
      # @param _coordinator [Karafka::Processing::Coordinator] processing coordinator that will
      #   be used with those messages
      # @yieldparam [Integer] group id
      # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
      def call(_topic, messages, _coordinator)
        yield(0, messages)
      end
    end
  end
end

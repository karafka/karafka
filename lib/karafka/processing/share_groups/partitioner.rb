# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Basic partitioner for share-group work division. Mirrors
      # {Processing::ConsumerGroups::Partitioner}: it does not divide the records of a single
      # topic partition any further.
      class Partitioner
        # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group
        def initialize(subscription_group)
          @subscription_group = subscription_group
        end

        # @param _topic [String] topic name
        # @param messages [Array<Karafka::Messages::Message>] karafka messages of one partition
        # @param _coordinator [Karafka::Processing::ShareGroups::Coordinator] processing
        #   coordinator that will be used with those messages
        # @yieldparam [Integer] group id
        # @yieldparam [Array<Karafka::Messages::Message>] karafka messages
        def call(_topic, messages, _coordinator)
          yield(0, messages)
        end
      end
    end
  end
end

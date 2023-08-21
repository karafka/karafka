# frozen_string_literal: true

module Karafka
  module Connection
    # Manages the subscriptions of a rdkafka consumer baesd on the routing state
    #
    # Subscriptions can be changed in some cases during runtime and if that happens, we need to
    # figure out the diff and be able to unsubscribe (when some topics removed) as well as
    # subscribe to newly added topics. This manager does that.
    class SubscriptionManager
      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @param consumer [Rdkafka::Consumer]
      def initialize(subscription_group, consumer)
        @subscription_group = subscription_group
        @consumer = consumer
        @active_subscriptions = []
      end

      # Updates the active subscriptions on the consumer if anything changed
      # If all the same, will do nothing
      #
      # @note It handles the removals by unsubscribing from all topics and subscribing again
      def refresh
        new_active_subscriptions = @subscription_group.subscriptions

        # Do nothing if there are no changes in the subscriptions
        return if @active_subscriptions == new_active_subscriptions

        newly_introduces = new_active_subscriptions - @active_subscriptions
        newly_lost = @active_subscriptions - new_active_subscriptions

        @consumer.unsubscribe unless newly_lost.empty?
        @consumer.subscribe(*newly_introduces)
        @active_subscriptions = new_active_subscriptions
      end
    end
  end
end

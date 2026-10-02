# frozen_string_literal: true

module Karafka
  module Connection
    # Builds the listener that matches a subscription group's mode. It encapsulates the
    # mode -> listener class mapping (consumer group vs share group) so the listeners batch does
    # not need to know about the per-mode listener classes.
    class ListenersBuilder
      # Builds a listener for the given subscription group.
      #
      # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group the
      #   listener will handle
      # @param jobs_queue [Karafka::Processing::JobsQueue, nil] jobs queue passed to the listener
      #   (consumer-group listeners use it; share-group listeners process inline and ignore it)
      # @param scheduler [Karafka::Processing::Scheduler, nil] scheduler passed to the listener
      # @return [Karafka::Connection::ConsumerGroups::Listener,
      #   Karafka::Connection::ShareGroups::Listener] listener matching the subscription group mode
      def call(subscription_group, jobs_queue, scheduler)
        listener_class_for(subscription_group).new(
          subscription_group,
          jobs_queue,
          scheduler
        )
      end

      private

      # Picks the listener class matching a subscription group's mode.
      #
      # @param subscription_group [Karafka::Routing::SubscriptionGroup]
      # @return [Class] the consumer-group or share-group listener class
      # @raise [Karafka::Errors::UnsupportedCaseError] when the group type is not recognized
      def listener_class_for(subscription_group)
        case subscription_group.group.group_type
        when :consumer
          Connection::ConsumerGroups::Listener
        when :share
          Connection::ShareGroups::Listener
        else
          raise Karafka::Errors::UnsupportedCaseError, subscription_group.group.group_type
        end
      end
    end
  end
end

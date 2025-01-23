# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      # Callback that connects to the librdkafka rebalance callback and converts those events into
      # our internal events
      class Rebalance
        include Helpers::ConfigImporter.new(
          monitor: %i[monitor]
        )

        # @param subscription_group [Karafka::Routes::SubscriptionGroup] subscription group for
        #   which we want to manage rebalances
        # @param client_id [String] id of the client managing this rebalance
        def initialize(subscription_group, client_id)
          @subscription_group = subscription_group
          @client_id = client_id
        end

        # Publishes an event that partitions are going to be revoked.
        # At this stage we can still commit offsets, etc.
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def on_partitions_revoke(tpl)
          instrument('partitions_revoke', tpl)
        end

        # Publishes an event that partitions are going to be assigned
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def on_partitions_assign(tpl)
          instrument('partitions_assign', tpl)
        end

        # Publishes an event that partitions were revoked. This is after we've lost them, so no
        # option to commit offsets.
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def on_partitions_revoked(tpl)
          instrument('partitions_revoked', tpl)
        end

        # Publishes an event that partitions were assigned.
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def on_partitions_assigned(tpl)
          instrument('partitions_assigned', tpl)
        end

        private

        # Publishes info that a rebalance event of a given type has happened
        #
        # @param name [String] name of the event
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def instrument(name, tpl)
          monitor.instrument(
            "rebalance.#{name}",
            caller: self,
            # We keep the id references here for backwards compatibility as some of the monitors
            # may use the id references
            subscription_group_id: @subscription_group.id,
            subscription_group: @subscription_group,
            consumer_group_id: @subscription_group.consumer_group.id,
            consumer_group: @subscription_group.consumer_group,
            client_id: @client_id,
            tpl: tpl
          )
        rescue StandardError => e
          monitor.instrument(
            'error.occurred',
            caller: self,
            subscription_group_id: @subscription_group.id,
            consumer_group_id: @subscription_group.consumer_group.id,
            type: "callbacks.rebalance.#{name}.error",
            client_id: @client_id,
            error: e
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      # Callback that connects to the librdkafka rebalance callback and converts those events into
      # our internal events
      class Rebalance
        # @param subscription_group_id [String] id of the current subscription group instance
        # @param consumer_group_id [String] id of the current consumer group
        def initialize(subscription_group_id, consumer_group_id)
          @subscription_group_id = subscription_group_id
          @consumer_group_id = consumer_group_id
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
          ::Karafka.monitor.instrument(
            "rebalance.#{name}",
            caller: self,
            subscription_group_id: @subscription_group_id,
            consumer_group_id: @consumer_group_id,
            tpl: tpl
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Patches
    module Rdkafka
      # Patches allowing us to run events on both pre and post rebalance events.
      # Thanks to that, we can easily connect to the whole flow despite of the moment when things
      # are happening
      module Opaque
        # Handles pre-assign phase of rebalance
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def call_on_partitions_assign(tpl)
          return unless consumer_rebalance_listener
          return unless consumer_rebalance_listener.respond_to?(:on_partitions_assign)

          consumer_rebalance_listener.on_partitions_assign(tpl)
        end

        # Handles pre-revoke phase of rebalance
        #
        # @param tpl [Rdkafka::Consumer::TopicPartitionList]
        def call_on_partitions_revoke(tpl)
          return unless consumer_rebalance_listener
          return unless consumer_rebalance_listener.respond_to?(:on_partitions_revoke)

          consumer_rebalance_listener.on_partitions_revoke(tpl)
        end
      end
    end
  end
end

::Rdkafka::Opaque.include(
  Karafka::Patches::Rdkafka::Opaque
)

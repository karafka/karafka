# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      module ConsumerGroups
        # Callback that connects to the librdkafka offset commit callback and publishes failed
        # offset commits. Without it, a failed async commit is only logged by librdkafka.
        class OffsetCommit
          include Helpers::ConfigImporter.new(
            monitor: %i[monitor]
          )

          # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group of
          #   the client that commits the offsets
          # @param client_id [String] id of the client that commits the offsets
          def initialize(subscription_group, client_id)
            @subscription_group = subscription_group
            @client_id = client_id
          end

          # Publishes an error when the offset commit failed
          #
          # @param error [Rdkafka::RdkafkaError, nil] commit error or nil on success
          # @param tpl [Rdkafka::Consumer::TopicPartitionList] offsets of the commit
          # @note We do not consider `no_offset` as an error. Every commit with nothing new stored
          #   reports it, same as in `Connection::Proxy#commit_offsets`.
          def on_offsets_committed(error, tpl)
            return unless error
            return if error.code == :no_offset

            instrument("connection.client.commit_offsets.error", error, tpl)
          rescue => e
            instrument("callbacks.offset_commit.error", e, tpl)
          end

          private

          # @param type [String] error type
          # @param error [StandardError] error to publish
          # @param tpl [Rdkafka::Consumer::TopicPartitionList] offsets of the commit
          def instrument(type, error, tpl)
            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group.id,
              consumer_group_id: @subscription_group.group.id,
              group_id: @subscription_group.group.id,
              client_id: @client_id,
              type: type,
              error: error,
              tpl: tpl
            )
          end
        end
      end
    end
  end
end

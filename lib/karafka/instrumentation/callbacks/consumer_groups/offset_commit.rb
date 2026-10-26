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

          # Publishes a failed offset commit
          #
          # @param error [Rdkafka::RdkafkaError] commit error
          # @param tpl [Rdkafka::Consumer::TopicPartitionList] offsets of the commit
          # @note rdkafka calls it only for failed commits: not on success and not on `no_offset`
          #   (nothing new to commit). The offsets of the other commits are then not converted to
          #   Ruby at all.
          # @note librdkafka also passes sync commit results here. We skip the errors that
          #   `Connection::Proxy#commit_offsets` handles without raising (e.g. a commit after the
          #   assignment was lost), as they are not errors for Karafka.
          def on_offsets_commit_failed(error, tpl)
            return if Connection::Proxy::COMMIT_HANDLED_ERRORS.include?(error.code)

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

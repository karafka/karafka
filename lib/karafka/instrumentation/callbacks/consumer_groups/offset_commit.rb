# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      module ConsumerGroups
        # Callback that connects to the librdkafka offset commit callback and publishes the
        # successful and the failed offset commits. Without it, a failed async commit is only
        # logged by librdkafka.
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
          #   (nothing new to commit).
          # @note librdkafka also passes sync commit results here. We skip the errors that
          #   `Connection::Proxy#commit_offsets` handles without raising (e.g. a commit after the
          #   assignment was lost), as they are not errors for Karafka.
          def on_offsets_commit_failed(error, tpl)
            return if Connection::Proxy::COMMIT_HANDLED_ERRORS.include?(error.code)

            instrument_error("connection.client.commit_offsets.error", error, tpl)
          rescue => e
            instrument_error("callbacks.offset_commit.error", e, tpl)
          end

          # Publishes a successful offset commit
          #
          # @param tpl [Rdkafka::Consumer::TopicPartitionList] offsets of the commit
          # @note rdkafka calls it only for successful commits: not on failures and not on
          #   `no_offset`. It is called for sync and async commits.
          # @note Karafka commits the stored offsets, so the list has every assigned partition. A
          #   partition with nothing committed has a nil offset.
          def on_offsets_commit_succeeded(tpl)
            monitor.instrument(
              "client.offsets.committed",
              caller: self,
              subscription_group_id: @subscription_group.id,
              subscription_group: @subscription_group,
              consumer_group_id: @subscription_group.group.id,
              consumer_group: @subscription_group.group,
              group_id: @subscription_group.group.id,
              group: @subscription_group.group,
              client_id: @client_id,
              tpl: tpl
            )
          rescue => e
            instrument_error("callbacks.offset_commit.error", e, tpl)
          end

          # @return [Boolean] true when something subscribes to `client.offsets.committed`
          # @note rdkafka asks it on each successful commit. Without a subscriber it does not
          #   convert the committed offsets, as their list has an entry for every assigned
          #   partition.
          def offsets_commit_succeeded_listened?
            listeners = monitor.listeners["client.offsets.committed"]

            !listeners.nil? && !listeners.empty?
          rescue => e
            instrument_error("callbacks.offset_commit.error", e, nil)

            false
          end

          private

          # @param type [String] error type
          # @param error [StandardError] error to publish
          # @param tpl [Rdkafka::Consumer::TopicPartitionList, nil] offsets of the commit, if any
          def instrument_error(type, error, tpl)
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

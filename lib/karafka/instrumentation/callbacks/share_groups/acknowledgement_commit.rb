# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      module ShareGroups
        # Callback invoked with the outcome of share-group acknowledgement commits, once per
        # partition per commit. It reports the acknowledgements the broker rejected, for example
        # when a record was acknowledged after its acquisition lock expired
        # (`invalid_record_state`): such a record was already handed back by the broker and will be
        # delivered again.
        #
        # @note librdkafka invokes it from within the share consumer poll and commit calls, so
        #   subscribers of the emitted event must not call the share client.
        class AcknowledgementCommit
          include Helpers::ConfigImporter.new(
            monitor: %i[monitor]
          )

          # @param subscription_group_id [String]
          # @param group_id [String] share group id reported in the emitted event payload
          def initialize(subscription_group_id, group_id)
            @subscription_group_id = subscription_group_id
            @group_id = group_id
          end

          # Reports rejected acknowledgements
          #
          # @param offsets [Array<Hash>] acknowledged offsets with their topic and partition
          # @param error [Rdkafka::RdkafkaError, nil] outcome for those offsets
          def call(offsets, error)
            return unless error

            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group_id,
              group_id: @group_id,
              offsets: offsets,
              type: "connection.client.acknowledgement.error",
              error: error
            )
          rescue => e
            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group_id,
              group_id: @group_id,
              type: "callbacks.acknowledgement_commit.error",
              error: e
            )
          end
        end
      end
    end
  end
end

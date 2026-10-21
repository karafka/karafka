# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      module ShareGroups
        # Callback that kicks in when a share consumer error occurs and is published in a background
        # thread. Mirror of the consumer-group error callback.
        class Error
          include Helpers::ConfigImporter.new(
            monitor: %i[monitor]
          )

          # @param subscription_group_id [String]
          # @param group_id [String] share group id reported in the emitted event payload
          # @param client_name [String] rdkafka client name
          def initialize(subscription_group_id, group_id, client_name)
            @subscription_group_id = subscription_group_id
            @group_id = group_id
            @client_name = client_name
          end

          # Runs the instrumentation monitor with error
          # @param client_name [String] rdkafka client name
          # @param error [Rdkafka::Error] error that occurred
          # @note It will only instrument on errors of the client of our consumer
          def call(client_name, error)
            # Emit only errors related to our client. Same as with statistics (more explanation
            # there)
            return unless @client_name == client_name

            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group_id,
              consumer_group_id: @group_id,
              group_id: @group_id,
              type: "librdkafka.error",
              error: error
            )
          rescue => e
            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group_id,
              consumer_group_id: @group_id,
              group_id: @group_id,
              type: "callbacks.error.error",
              error: e
            )
          end
        end
      end
    end
  end
end

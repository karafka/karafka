# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      # Share-group (KIP-932) rdkafka callbacks. Mirror of the consumer-group callbacks - kept as a
      # separate per-mode namespace so share-group and consumer-group instrumentation can diverge
      # (different statistics semantics, no rebalance) without conditionals in the shared code.
      module ShareGroups
        # Statistics callback handler for share consumers.
        #
        # librdkafka 2.15 emits the regular consumer statistics JSON (including `cgrp`, with no
        # share-specific section) for share consumers, serviced from within `#poll`. We therefore
        # decorate and emit them the same way as consumer-group statistics, using the generic
        # statistics decorator directly (there is no share-specific lag/pause compensation to
        # apply).
        class Statistics
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
            @statistics_decorator = ::Karafka::Core::Monitoring::StatisticsDecorator.new
          end

          # Emits decorated statistics to the monitor
          # @param statistics [Hash] rdkafka statistics
          def call(statistics)
            # Emit only statistics related to our client. rdkafka does not have per-instance
            # statistics hook, thus we need to make sure that we emit only stats that are related
            # to the current client. Otherwise we would emit all of them all the time.
            return unless @client_name == statistics["name"]

            monitor.instrument(
              "statistics.emitted",
              subscription_group_id: @subscription_group_id,
              consumer_group_id: @group_id,
              group_id: @group_id,
              statistics: @statistics_decorator.call(statistics)
            )
          # We need to catch and handle any potential errors coming from the instrumentation pipeline
          # as otherwise, in case of statistics which run in the main librdkafka thread, any crash
          # will hang the whole process.
          rescue => e
            monitor.instrument(
              "error.occurred",
              caller: self,
              subscription_group_id: @subscription_group_id,
              consumer_group_id: @group_id,
              group_id: @group_id,
              type: "callbacks.statistics.error",
              error: e
            )
          end
        end
      end
    end
  end
end

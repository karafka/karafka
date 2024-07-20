# frozen_string_literal: true

module Karafka
  module Instrumentation
    module Callbacks
      # Statistics callback handler
      # @see `WaterDrop::Instrumentation::Callbacks::Statistics` for details on why we decorate
      #   those statistics
      class Statistics
        include Helpers::ConfigImporter.new(
          monitor: %i[monitor]
        )

        # @param subscription_group_id [String] id of the current subscription group
        # @param consumer_group_id [String] id of the current consumer group
        # @param client_name [String] rdkafka client name
        def initialize(subscription_group_id, consumer_group_id, client_name)
          @subscription_group_id = subscription_group_id
          @consumer_group_id = consumer_group_id
          @client_name = client_name
          @statistics_decorator = ::Karafka::Core::Monitoring::StatisticsDecorator.new
        end

        # Emits decorated statistics to the monitor
        # @param statistics [Hash] rdkafka statistics
        def call(statistics)
          # Emit only statistics related to our client
          # rdkafka does not have per-instance statistics hook, thus we need to make sure that we
          # emit only stats that are related to current producer. Otherwise we would emit all of
          # all the time.
          return unless @client_name == statistics['name']

          monitor.instrument(
            'statistics.emitted',
            subscription_group_id: @subscription_group_id,
            consumer_group_id: @consumer_group_id,
            statistics: @statistics_decorator.call(statistics)
          )
        # We need to catch and handle any potential errors coming from the instrumentation pipeline
        # as otherwise, in case of statistics which run in the main librdkafka thread, any crash
        # will hang the whole process.
        rescue StandardError => e
          monitor.instrument(
            'error.occurred',
            caller: self,
            subscription_group_id: @subscription_group_id,
            consumer_group_id: @consumer_group_id,
            type: 'callbacks.statistics.error',
            error: e
          )
        end
      end
    end
  end
end

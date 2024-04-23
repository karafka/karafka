# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Callbacks used to transport things from rdkafka
    module Callbacks
      # Callback that kicks in when consumer error occurs and is published in a background thread
      class Error
        include Helpers::ConfigImporter.new(
          monitor: %i[monitor]
        )

        # @param subscription_group_id [String] id of the current subscription group instance
        # @param consumer_group_id [String] id of the current consumer group
        # @param client_name [String] rdkafka client name
        def initialize(subscription_group_id, consumer_group_id, client_name)
          @subscription_group_id = subscription_group_id
          @consumer_group_id = consumer_group_id
          @client_name = client_name
        end

        # Runs the instrumentation monitor with error
        # @param client_name [String] rdkafka client name
        # @param error [Rdkafka::Error] error that occurred
        # @note It will only instrument on errors of the client of our consumer
        def call(client_name, error)
          # Emit only errors related to our client
          # Same as with statistics (mor explanation there)
          return unless @client_name == client_name

          monitor.instrument(
            'error.occurred',
            caller: self,
            subscription_group_id: @subscription_group_id,
            consumer_group_id: @consumer_group_id,
            type: 'librdkafka.error',
            error: error
          )
        rescue StandardError => e
          monitor.instrument(
            'error.occurred',
            caller: self,
            subscription_group_id: @subscription_group_id,
            consumer_group_id: @consumer_group_id,
            type: 'callbacks.error.error',
            error: e
          )
        end
      end
    end
  end
end

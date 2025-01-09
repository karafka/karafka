# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Setup and config related recurring tasks components
      module Setup
        # Config for recurring tasks
        class Config
          extend ::Karafka::Core::Configurable

          setting(:consumer_class, default: Consumer)
          setting(:group_id, default: 'karafka_scheduled_messages')

          # By default we will run the scheduling every 15 seconds since we provide a minute-based
          # precision. Can be increased when having dedicated processes to run this. Lower values
          # mean more frequent execution on low-throughput topics meaning higher precision.
          setting(:interval, default: 15_000)

          # How many messages should be flush in one go from the dispatcher at most. If we have
          # more messages to dispatch, they will be chunked.
          setting(:flush_batch_size, default: 1_000)

          # Producer to use. By default uses default Karafka producer.
          setting(
            :producer,
            constructor: -> { ::Karafka.producer },
            lazy: true
          )

          # Class we use to dispatch messages
          setting(:dispatcher_class, default: Dispatcher)

          # Postfix for the states topic to build the states based on the group name + postfix
          setting(:states_postfix, default: '_states')

          setting(:deserializers) do
            # Deserializer for schedules messages to convert epochs
            setting(:headers, default: Deserializers::Headers.new)
            # Only applicable to states
            setting(:payload, default: Deserializers::Payload.new)
          end

          configure
        end
      end
    end
  end
end

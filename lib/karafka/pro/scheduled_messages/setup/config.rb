# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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

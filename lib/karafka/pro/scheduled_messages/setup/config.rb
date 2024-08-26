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
          # precision
          setting(:interval, default: 15_000)

          # Should we log the dispatches. If true (default) with each cron execution, there will
          # be a special message published. Useful for debugging.
          setting(:logging, default: true)

          setting(
            :producer,
            constructor: -> { ::Karafka.producer },
            lazy: true
          )

          setting(:deserializers) do
            setting(:headers, default: Deserializers::Headers.new)
            setting(:offset_metadata, default: Deserializers::OffsetMetadata.new)
          end

          setting(:topics) do
            setting(:messages, default: 'karafka_scheduled_messages')
            setting(:logs, default: 'karafka_scheduled_logs')
          end

          configure
        end
      end
    end
  end
end

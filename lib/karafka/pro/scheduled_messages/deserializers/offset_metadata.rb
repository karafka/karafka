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
      # Namespace for deserializers needed when working with scheduled messages
      module Deserializers
        # Extracts the offset metadata details
        # We store in the offset metadata the last timestamp that we dispatched. Used for recovery.
        # We store it as JSON so we can expand it when needed in the future with other attributes.
        class OffsetMetadata
          DEFAULTS = {
            last_dispatched_time: -1
          }.freeze

          private_constant :DEFAULTS

          def call(raw_metadata)
            raw_metadata ? JSON.parse(raw_metadata, symbolize_names: true) : DEFAULTS
          end
        end
      end
    end
  end
end

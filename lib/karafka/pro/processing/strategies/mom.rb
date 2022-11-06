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
    module Processing
      module Strategies
        # Manual offset management enabled
        module Mom
          include Default

          # Features for this strategy
          FEATURES = %i[
            manual_offset_management
          ].freeze

          # When mom is enabled, we do not mark messages as consumed after processing
          def handle_after_consume
            coordinator.on_finished do
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset
              else
                pause(coordinator.seek_offset)
              end
            end
          end
        end
      end
    end
  end
end

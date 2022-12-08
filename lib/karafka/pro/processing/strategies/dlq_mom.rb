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
        # Strategy for supporting DLQ with Mom enabled
        module DlqMom
          # The broken message lookup is the same in this scenario
          include Dlq

          # Features for this strategy
          FEATURES = %i[
            dead_letter_queue
            manual_offset_management
          ].freeze

          # When manual offset management is on, we do not mark anything as consumed automatically
          # and we rely on the user to figure things out
          def handle_after_consume
            coordinator.on_finished do
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset
              elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                retry_after_pause
              # If we've reached number of retries that we could, we need to skip the first message
              # that was not marked as consumed, pause and continue, while also moving this message
              # to the dead topic.
              #
              # For a Mom setup, this means, that user has to manage the checkpointing by himself.
              # If no checkpointing is ever done, we end up with an endless loop.
              else
                # We reset the pause to indicate we will now consider it as "ok".
                coordinator.pause_tracker.reset

                if dispatch_to_dlq?
                  skippable_message = find_skippable_message
                  dispatch_to_dlq(skippable_message)
                end

                pause(coordinator.seek_offset, nil, false)
              end
            end
          end
        end
      end
    end
  end
end

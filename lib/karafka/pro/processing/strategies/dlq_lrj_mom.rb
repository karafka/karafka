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
        # Strategy for supporting DLQ with Mom and LRJ enabled
        module DlqLrjMom
          # This strategy needs to pause and revoke same way as DlqLrj but without the offset
          # management
          include DlqLrj

          # Features for this strategy
          FEATURES = %i[
            dead_letter_queue
            long_running_job
            manual_offset_management
          ].freeze

          # LRJ standard flow after consumption with DLQ dispatch and no offset management
          def handle_after_consume
            coordinator.on_finished do
              if coordinator.success?
                coordinator.pause_tracker.reset

                seek(coordinator.seek_offset) unless revoked?

                resume
              elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                pause(coordinator.seek_offset)
              else
                coordinator.pause_tracker.reset

                unless revoked?
                  if dispatch_to_dlq?
                    skippable_message = find_skippable_message
                    dispatch_to_dlq(skippable_message)
                  end

                  seek(coordinator.seek_offset)
                end

                resume
              end
            end
          end
        end
      end
    end
  end
end

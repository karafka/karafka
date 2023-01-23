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
        # ActiveJob enabled
        # DLQ enabled
        # Long-Running Job enabled
        # Manual offset management enabled
        # Virtual Partitions enabled
        #
        # This case is a bit of special. Please see the `AjDlqMom` for explanation on how the
        # offset management works in this case.
        module AjDlqLrjMomVp
          include AjDlqMomVp
          include AjLrjMom

          # Features for this strategy
          FEATURES = %i[
            active_job
            long_running_job
            manual_offset_management
            dead_letter_queue
            virtual_partitions
          ].freeze

          # This strategy is pretty much as non VP one because of the collapse
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              if coordinator.success?
                coordinator.pause_tracker.reset

                return if revoked?
                return if Karafka::App.stopping?

                # Since we have VP here we do not commit intermediate offsets and need to commit
                # them here. We do commit in collapsed mode but this is generalized.
                mark_as_consumed(last_group_message)

                seek(coordinator.seek_offset) unless revoked?

                resume
              elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                retry_after_pause
              else
                coordinator.pause_tracker.reset
                skippable_message = find_skippable_message
                dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                mark_as_consumed(skippable_message)
                pause(coordinator.seek_offset, nil, false)
              end
            end
          end
        end
      end
    end
  end
end

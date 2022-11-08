# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # Same as pure dead letter queue but we do not marked failed message as consumed
      module DlqMom
        include Dlq

        # Apply strategy when dlq is on with manual offset management
        FEATURES = %i[
          dead_letter_queue
          manual_offset_management
        ].freeze

        # When manual offset management is on, we do not mark anything as consumed automatically
        # and we rely on the user to figure things out
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset
          elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
            pause(coordinator.seek_offset)
          # If we've reached number of retries that we could, we need to skip the first message
          # that was not marked as consumed, pause and continue, while also moving this message
          # to the dead topic
          else
            # We reset the pause to indicate we will now consider it as "ok".
            coordinator.pause_tracker.reset

            skippable_message = find_skippable_message
            dispatch_to_dlq(skippable_message)

            # We pause to backoff once just in case.
            pause(coordinator.seek_offset)
          end
        end
      end
    end
  end
end

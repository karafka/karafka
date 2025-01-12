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
            retry_after_pause
          # If we've reached number of retries that we could, we need to skip the first message
          # that was not marked as consumed, pause and continue, while also moving this message
          # to the dead topic
          else
            # We reset the pause to indicate we will now consider it as "ok".
            coordinator.pause_tracker.reset

            skippable_message, = find_skippable_message

            dispatch_to_dlq(skippable_message)

            # We mark the broken message as consumed and move on
            if mark_after_dispatch?
              mark_dispatched_to_dlq(skippable_message)

              return if revoked?
            else
              # Save the next offset we want to go with after moving given message to DLQ
              # Without this, we would not be able to move forward and we would end up
              # in an infinite loop trying to un-pause from the message we've already processed
              # Of course, since it's a MoM a rebalance or kill, will move it back as no
              # offsets are being committed
              self.seek_offset = skippable_message.offset + 1
            end

            pause(seek_offset, nil, false)
          end
        end

        # @return [Boolean] should we mark given message as consumed after dispatch. For
        #  MOM strategies if user did not explicitly tell us to mark, we do not mark. Default is
        #  `nil`, which means `false` in this case. If user provided alternative value, we go
        #  with it.
        #
        # @note Please note, this is the opposite behavior than in case of AOM strategies.
        def mark_after_dispatch?
          return false if topic.dead_letter_queue.mark_after_dispatch.nil?

          topic.dead_letter_queue.mark_after_dispatch
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # ActiveJob strategy to cooperate with the DLQ.
      #
      # While AJ is uses MOM by default because it delegates the offset management to the AJ
      # consumer. With DLQ however there is an extra case for skipping broken jobs with offset
      # marking due to ordered processing.
      module AjDlqMom
        include DlqMom

        # Apply strategy when only when using AJ with MOM and DLQ
        FEATURES = %i[
          active_job
          dead_letter_queue
          manual_offset_management
        ].freeze

        # How should we post-finalize consumption.
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            # Do NOT commit offsets, they are comitted after each job in the AJ consumer.
            coordinator.pause_tracker.reset
          elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
            retry_after_pause
          else
            coordinator.pause_tracker.reset
            skippable_message, = find_skippable_message
            dispatch_to_dlq(skippable_message)
            # We can commit the offset here because we know that we skip it "forever" and
            # since AJ consumer commits the offset after each job, we also know that the
            # previous job was successful
            mark_dispatched_to_dlq(skippable_message)
            pause(seek_offset, nil, false)
          end
        end
      end
    end
  end
end

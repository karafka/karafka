# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # No features enabled.
      # No manual offset management
      # No long running jobs
      # Nothing. Just standard, automatic flow
      module Default
        include Base

        # Apply strategy for a non-feature based flow
        FEATURES = %i[].freeze

        # No actions needed for the standard flow here
        def handle_before_enqueue
          nil
        end

        # Increment number of attempts
        def handle_before_consume
          coordinator.pause_tracker.increment
        end

        # Run the user consumption code
        def handle_consume
          Karafka.monitor.instrument('consumer.consumed', caller: self) do
            consume
          end

          # Mark job as successful
          coordinator.consumption(self).success!
        rescue StandardError => e
          # If failed, mark as failed
          coordinator.consumption(self).failure!(e)

          # Re-raise so reported in the consumer
          raise e
        ensure
          # We need to decrease number of jobs that this coordinator coordinates as it has finished
          coordinator.decrement
        end

        # Standard flow marks work as consumed and moves on if everything went ok.
        # If there was a processing error, we will pause and continue from the next message
        # (next that is +1 from the last one that was successfully marked as consumed)
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset

            mark_as_consumed(messages.last)
          else
            pause(coordinator.seek_offset)
          end
        end

        # We need to always un-pause the processing in case we have lost a given partition.
        # Otherwise the underlying librdkafka would not know we may want to continue processing and
        # the pause could in theory last forever
        def handle_revoked
          resume

          coordinator.revoke
        end
      end
    end
  end
end

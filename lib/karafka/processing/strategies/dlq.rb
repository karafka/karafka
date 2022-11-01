# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # When using dead letter queue, processing won't stop after defined number of retries
      # upon encountering non-critical errors but the messages that error will be moved to a
      # separate topic with their payload and metadata, so they can be handled differently.
      module Dlq
        include Base

        # Apply strategy when only dead letter queue is turned on
        FEATURES = %i[
          dead_letter_queue
        ].freeze

        # No actions needed for the standard flow here
        def handle_before_enqueue
          nil
        end

        # When manual offset management is on, we do not mark anything as consumed automatically
        # and we rely on the user to figure things out
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset

            mark_as_consumed(messages.last)
          else
            # If we can still retry, just pause and try again
            if coordinator.pause_tracker.count < topic.dead_letter_queue.max_retries
              pause(coordinator.seek_offset)
            # If we've reached number of retries that we could, we need to skip the first message
            # that was not marked as consumed, pause and continue, while also moving this message
            # to the dead topic
            else
              # We reset the pause to indicate we will now consider it as "ok".
              coordinator.pause_tracker.reset

              # Find the first message that was not marked as consumed
              broken = messages.find { |message| message.offset == coordinator.seek_offset }

              # Failsafe, should never happen
              broken || raise(Errors::SkipMessageNotFoundError, topic.name)

              # Move broken message into the dead letter topic
              producer.produce_async(
                topic: topic.dead_letter_queue.topic,
                payload: broken.raw_payload
              )

              # We mark the broken message as consumed and move on
              mark_as_consumed(
                Messages::Seek.new(
                  topic.name,
                  messages.metadata.partition,
                  coordinator.seek_offset
                )
              )

              # We pause to backoff once just in case.
              pause(coordinator.seek_offset)
            end
          end
        end

        # Same as default
        def handle_revoked
          resume

          coordinator.revoke
        end
      end
    end
  end
end

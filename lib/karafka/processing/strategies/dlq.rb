# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # When using dead letter queue, processing won't stop after defined number of retries
      # upon encountering non-critical errors but the messages that error will be moved to a
      # separate topic with their payload and metadata, so they can be handled differently.
      module Dlq
        include Default

        # Apply strategy when only dead letter queue is turned on
        FEATURES = %i[
          dead_letter_queue
        ].freeze

        # When manual offset management is on, we do not mark anything as consumed automatically
        # and we rely on the user to figure things out
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset

            mark_as_consumed(messages.last)
          elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
            pause(coordinator.seek_offset)
          # If we've reached number of retries that we could, we need to skip the first message
          # that was not marked as consumed, pause and continue, while also moving this message
          # to the dead topic
          else
            # We reset the pause to indicate we will now consider it as "ok".
            coordinator.pause_tracker.reset

            skippable_message = find_skippable_message

            # Send skippable message to the dql topic
            dispatch_to_dlq(skippable_message)

            # We mark the broken message as consumed and move on
            mark_as_consumed(skippable_message)

            return if revoked?

            # We pause to backoff once just in case.
            pause(coordinator.seek_offset)
          end
        end

        # Finds the message we want to skip
        # @private
        def find_skippable_message
          skippable_message = messages.find { |message| message.offset == coordinator.seek_offset }
          skippable_message || raise(Errors::SkipMessageNotFoundError, topic.name)
        end

        # Moves the broken message into a separate queue defined via the settings
        # @private
        # @param skippable_message [Karafka::Messages::Message] message we are skipping that also
        #   should go to the dlq topic
        def dispatch_to_dlq(skippable_message)
          producer.produce_async(
            topic: topic.dead_letter_queue.topic,
            payload: skippable_message.raw_payload
          )

          # Notify about dispatch on the events bus
          Karafka.monitor.instrument(
            'dead_letter_queue.dispatched',
            caller: self,
            message: skippable_message
          )
        end
      end
    end
  end
end

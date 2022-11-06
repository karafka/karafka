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
        # Only dead letter queue enabled
        module Dlq
          include Default

          # Features for this strategy
          FEATURES = %i[
            dead_letter_queue
          ].freeze

          # When we encounter non-recoverable message, we skip it and go on with our lives
          def handle_after_consume
            coordinator.on_finished do
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
                dispatch_skippable_message_to_dlq(skippable_message)
                mark_as_consumed(skippable_message)
                pause(coordinator.seek_offset)
              end
            end
          end

          # Finds the message may want to skip (all, starting from first)
          # @private
          # @return [Karafka::Messages::Message] message we may want to skip
          def find_skippable_message
            skippable_message = messages.find { |msg| msg.offset == coordinator.seek_offset }
            skippable_message || raise(Errors::SkipMessageNotFoundError, topic.name)
          end

          # Moves the broken message into a separate queue defined via the settings
          #
          # @private
          # @param skippable_message [Array<Karafka::Messages::Message>] message we want to
          #   dispatch to DLQ
          def dispatch_skippable_message_to_dlq(skippable_message)
            producer.produce_async(
              topic: topic.dead_letter_queue.topic,
              payload: skippable_message.raw_payload,
              key: skippable_message.partition.to_s,
              headers: skippable_message.headers.merge(
                'original-partition' => skippable_message.partition.to_s,
                'original-offset' => skippable_message.offset.to_s
              )
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
end

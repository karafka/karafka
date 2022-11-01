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

                case topic.dead_letter_queue.skip
                when :one
                  # Move broken message into the dead letter topic
                  producer.produce_async(
                    topic: topic.dead_letter_queue.topic,
                    payload: broken.raw_payload,
                    # Include original metadata
                    metadata: broken.metadata,
                    # Support strong ordering
                    key: broken.partition
                  )

                  # We mark the broken message as consumed and move on
                  mark_as_consumed(
                    Messages::Seek.new(
                      topic.name,
                      messages.metadata.partition,
                      coordinator.seek_offset
                    )
                  )
                when :many
                  messages
                    .select { |message| message.offset >= broken.offset }
                    .each do |message|
                      producer.produce_async(
                        topic: topic.dead_letter_queue.topic,
                        payload: broken.raw_payload,
                        # Include original metadata
                        metadata: broken.metadata,
                        # Support strong ordering
                        key: broken.partition
                      )
                  end

                  mark_as_consumed(messages.last)
                else
                  raise Errors::UnsupportedCaseError, topic.dead_letter_queue.skip
                end

                # We pause to backoff once just in case.
                pause(coordinator.seek_offset)
              end
            end
          end
        end
      end
    end
  end
end

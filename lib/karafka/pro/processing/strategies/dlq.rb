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

                first_skippable = find_first_skippable_message

                case topic.dead_letter_queue.skip
                when :one
                  skippables = [first_skippable]
                when :many
                  skippables = messages.select do |message|
                    message.offset >= first_skippable.offset
                  end
                else
                  raise Errors::UnsupportedCaseError, topic.dead_letter_queue.skip
                end

                copy_skippable_messages_to_dlq(skippables)
                mark_as_consumed(skippables.last)
                pause(coordinator.seek_offset)
              end
            end
          end

          # Finds the message we want to skip
          # @private
          def find_first_skippable_message
            skippable_message = messages.find { |message| message.offset == coordinator.seek_offset }
            skippable_message || raise(Errors::SkipMessageNotFoundError, topic.name)
          end

          # Finds and moves the broken message into a separate queue defined via the settings
          # @private
          # @param skippable_message [Karafka::Messages::Message] message we are skipping that also
          #   should go to the dlq topic
          def copy_skippable_messages_to_dlq(skippable_messages)
            dispatch = skippable_messages.map do |skippable_message|
              {
                topic: topic.dead_letter_queue.topic,
                payload: skippable_message.raw_payload,
                headers: skippable_message.headers.merge(
                  'original-partition' => skippable_message.partition.to_s
                ),
                key: skippable_message.partition.to_s
              }
            end

            producer.produce_many_async(dispatch)
          end
        end
      end
    end
  end
end

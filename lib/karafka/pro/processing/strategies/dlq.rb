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

                return if coordinator.manual_pause?

                mark_as_consumed(messages.last)
              elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                retry_after_pause
              # If we've reached number of retries that we could, we need to skip the first message
              # that was not marked as consumed, pause and continue, while also moving this message
              # to the dead topic
              else
                # We reset the pause to indicate we will now consider it as "ok".
                coordinator.pause_tracker.reset
                skippable_message = find_skippable_message
                dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                mark_as_consumed(skippable_message)
                pause(coordinator.seek_offset, nil, false)
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
          # @param skippable_message [Array<Karafka::Messages::Message>] message we want to
          #   dispatch to DLQ
          def dispatch_to_dlq(skippable_message)
            producer.produce_async(
              build_dlq_message(
                skippable_message
              )
            )

            # Notify about dispatch on the events bus
            Karafka.monitor.instrument(
              'dead_letter_queue.dispatched',
              caller: self,
              message: skippable_message
            )
          end

          # @param skippable_message [Array<Karafka::Messages::Message>]
          # @return [Hash] dispatch DLQ message
          def build_dlq_message(skippable_message)
            original_partition = skippable_message.partition.to_s

            dlq_message = {
              topic: topic.dead_letter_queue.topic,
              key: original_partition,
              payload: skippable_message.raw_payload,
              headers: skippable_message.headers.merge(
                'original_topic' => topic.name,
                'original_partition' => original_partition,
                'original_offset' => skippable_message.offset.to_s,
                'original_consumer_group' => topic.consumer_group.id
              )
            }

            # Optional method user can define in consumer to enhance the dlq message hash with
            # some extra details if needed or to replace payload, etc
            if respond_to?(:enhance_dlq_message, true)
              enhance_dlq_message(
                dlq_message,
                skippable_message
              )
            end

            dlq_message
          end

          # @return [Boolean] should we dispatch the message to DLQ or not. When the dispatch topic
          #   is set to false, we will skip the dispatch, effectively ignoring the broken message
          #   without taking any action.
          def dispatch_to_dlq?
            topic.dead_letter_queue.topic
          end
        end
      end
    end
  end
end

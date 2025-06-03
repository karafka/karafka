# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for all the strategies starting with DLQ
        module Dlq
          # Only dead letter queue enabled
          module Default
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
            ].freeze

            # Override of the standard `#mark_as_consumed` in order to handle the pause tracker
            # reset in case DLQ is marked as fully independent. When DLQ is marked independent,
            # any offset marking causes the pause count tracker to reset. This is useful when
            # the error is not due to the collective batch operations state but due to intermediate
            # "crawling" errors that move with it
            #
            # @see `Strategies::Default#mark_as_consumed` for more details
            # @param message [Messages::Message]
            # @param offset_metadata [String, nil]
            def mark_as_consumed(message, offset_metadata = @_current_offset_metadata)
              return super unless retrying?
              return super unless topic.dead_letter_queue.independent?
              return false unless super

              coordinator.pause_tracker.reset

              true
            ensure
              @_current_offset_metadata = nil
            end

            # Override of the standard `#mark_as_consumed!`. Resets the pause tracker count in case
            # DLQ was configured with the `independent` flag.
            #
            # @see `Strategies::Default#mark_as_consumed!` for more details
            # @param message [Messages::Message]
            # @param offset_metadata [String, nil]
            def mark_as_consumed!(message, offset_metadata = @_current_offset_metadata)
              return super unless retrying?
              return super unless topic.dead_letter_queue.independent?
              return false unless super

              coordinator.pause_tracker.reset

              true
            ensure
              @_current_offset_metadata = nil
            end

            # When we encounter non-recoverable message, we skip it and go on with our lives
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message)
                else
                  apply_dlq_flow do
                    dispatch_if_needed_and_mark_as_consumed
                  end
                end
              end
            end

            # Finds the message may want to skip (all, starting from first)
            # @private
            # @return [Array<Karafka::Messages::Message, Boolean>] message we may want to skip and
            #   information if this message was from marked offset or figured out via mom flow
            def find_skippable_message
              skippable_message = messages.find do |msg|
                coordinator.marked? && msg.offset == seek_offset
              end

              # If we don't have the message matching the last comitted offset, it means that
              # user operates with manual offsets and we're beyond the batch in which things
              # broke for the first time. Then we skip the first (as no markings) and we
              # move on one by one.
              skippable_message ? [skippable_message, true] : [messages.first, false]
            end

            # Moves the broken message into a separate queue defined via the settings
            #
            # @param skippable_message [Array<Karafka::Messages::Message>] message we want to
            #   dispatch to DLQ
            def dispatch_to_dlq(skippable_message)
              # DLQ should never try to dispatch a message that was cleaned. It message was
              # cleaned, we will not have all the needed data. If you see this error, it means
              # that your processing flow is not as expected and you have cleaned message that
              # should not be cleaned as it should go to the DLQ
              raise(Cleaner::Errors::MessageCleanedError) if skippable_message.cleaned?

              producer.public_send(
                topic.dead_letter_queue.dispatch_method,
                build_dlq_message(
                  skippable_message
                )
              )

              # Notify about dispatch on the events bus
              monitor.instrument(
                'dead_letter_queue.dispatched',
                caller: self,
                message: skippable_message
              )
            end

            # Dispatches the message to the DLQ (when needed and when applicable based on settings)
            #   and marks this message as consumed for non MOM flows.
            #
            # If producer is transactional and config allows, uses transaction to do that
            def dispatch_if_needed_and_mark_as_consumed
              skippable_message, = find_skippable_message

              dispatch = lambda do
                dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                if mark_after_dispatch?
                  mark_dispatched_to_dlq(skippable_message)
                else
                  self.seek_offset = skippable_message.offset + 1
                end
              end

              if dispatch_in_a_transaction?
                transaction { dispatch.call }
              else
                dispatch.call
              end
            end

            # @param skippable_message [Array<Karafka::Messages::Message>]
            # @return [Hash] dispatch DLQ message
            def build_dlq_message(skippable_message)
              source_partition = skippable_message.partition.to_s

              dlq_message = {
                topic: @_dispatch_to_dlq_topic || topic.dead_letter_queue.topic,
                key: skippable_message.raw_key,
                partition_key: source_partition,
                payload: skippable_message.raw_payload,
                headers: skippable_message.raw_headers.merge(
                  'source_topic' => topic.name,
                  'source_partition' => source_partition,
                  'source_offset' => skippable_message.offset.to_s,
                  'source_consumer_group' => topic.consumer_group.id,
                  'source_attempts' => attempt.to_s,
                  'source_trace_id' => errors_tracker.trace_id
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

            # @return [Boolean] should we dispatch the message to DLQ or not. When the dispatch
            #   topic is set to false, we will skip the dispatch, effectively ignoring the broken
            #   message without taking any action.
            def dispatch_to_dlq?
              return false unless topic.dead_letter_queue.topic
              return false unless @_dispatch_to_dlq

              true
            end

            # @return [Boolean] should we use a transaction to move the data to the DLQ.
            #   We can do it only when producer is transactional and configuration for DLQ
            #   transactional dispatches is not set to false.
            def dispatch_in_a_transaction?
              producer.transactional? && topic.dead_letter_queue.transactional?
            end

            # @return [Boolean] should we mark given message as consumed after dispatch.
            #  For default non MOM strategies if user did not explicitly tell us not to, we mark
            #  it. Default is `nil`, which means `true` in this case. If user provided alternative
            #  value, we go with it.
            def mark_after_dispatch?
              return true if topic.dead_letter_queue.mark_after_dispatch.nil?

              topic.dead_letter_queue.mark_after_dispatch
            end

            # Runs the DLQ strategy and based on it it performs certain operations
            #
            # In case of `:skip` and `:dispatch` will run the exact flow provided in a block
            # In case of `:retry` always `#retry_after_pause` is applied
            def apply_dlq_flow
              flow, target_topic = topic.dead_letter_queue.strategy.call(errors_tracker, attempt)

              case flow
              when :retry
                retry_after_pause

                return
              when :skip
                @_dispatch_to_dlq = false
              when :dispatch
                @_dispatch_to_dlq = true
                # Use custom topic if it was returned from the strategy
                @_dispatch_to_dlq_topic = target_topic || topic.dead_letter_queue.topic
              else
                raise Karafka::UnsupportedCaseError, flow
              end

              yield

              # We reset the pause to indicate we will now consider it as "ok".
              coordinator.pause_tracker.reset

              # Always backoff after DLQ dispatch even on skip to prevent overloads on errors
              pause(seek_offset, nil, false)
            ensure
              @_dispatch_to_dlq_topic = nil
            end

            # Marks message that went to DLQ (if applicable) based on the requested method
            # @param skippable_message [Karafka::Messages::Message]
            def mark_dispatched_to_dlq(skippable_message)
              case topic.dead_letter_queue.marking_method
              when :mark_as_consumed
                mark_as_consumed(skippable_message)
              when :mark_as_consumed!
                mark_as_consumed!(skippable_message)
              else
                # This should never happen. Bug if encountered. Please report
                raise Karafka::Errors::UnsupportedCaseError
              end
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      module Strategies
        # When using dead letter queue, records that keep failing are moved to a separate topic
        # after a defined number of retries, instead of being redelivered until the broker drops
        # them at the share group delivery count limit. Mirrors
        # {Processing::ConsumerGroups::Strategies::Dlq}: retries are counted with the record
        # delivery count instead of the pause tracker.
        module Dlq
          include Default

          # Apply strategy when only dead letter queue is turned on
          FEATURES = %i[
            dead_letter_queue
          ].freeze

          # After a failure, every record left unacknowledged that was already delivered more
          # times than allowed is dispatched to the DLQ topic and rejected, so the broker does not
          # deliver it again. The rest is released for another attempt.
          def handle_after_consume
            consumption = coordinator.consumption(self)

            # Process-critical errors are never dispatched to the DLQ regardless of the retries
            # state, same as for consumer groups - the records are redelivered after the restart
            if !consumption.success? && !critical_error?(consumption.cause)
              messages.each do |message|
                next if message.delivery_count <= topic.dead_letter_queue.max_retries
                next unless client.pending?(message)

                # The record is gone once rejected, so it has to be dispatched first
                dispatch_to_dlq(message) if topic.dead_letter_queue.topic

                client.mark_as_rejected(message)
              end
            end

            super
          end

          # Moves the broken record into a separate queue defined via the settings
          # @private
          # @param message [Karafka::Messages::Message] record that should go to the dlq topic
          def dispatch_to_dlq(message)
            producer.public_send(
              topic.dead_letter_queue.dispatch_method,
              topic: topic.dead_letter_queue.topic,
              payload: message.raw_payload
            )

            # Notify about dispatch on the events bus
            monitor.instrument(
              "dead_letter_queue.dispatched",
              caller: self,
              message: message
            )
          end
        end
      end
    end
  end
end

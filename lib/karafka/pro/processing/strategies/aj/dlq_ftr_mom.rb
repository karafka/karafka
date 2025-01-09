# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # - Aj
          # - Dlq
          # - Ftr
          # - Mom
          module DlqFtrMom
            include Strategies::Dlq::FtrMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              filtering
              manual_offset_management
            ].freeze

            # We write our own custom handler for after consume here, because we mark as consumed
            # per each job in the AJ consumer itself (for this strategy). This means, that for DLQ
            # dispatch, we can mark this message as consumed as well.
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  handle_post_filtering
                # If we've reached number of retries that we could, we need to skip the first
                # message that was not marked as consumed, pause and continue, while also moving
                # this message to the dead topic.
                #
                # For a Mom setup, this means, that user has to manage the checkpointing by
                # himself. If no checkpointing is ever done, we end up with an endless loop.
                else
                  apply_dlq_flow do
                    skippable_message, = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                    # We can commit the offset here because we know that we skip it "forever" and
                    # since AJ consumer commits the offset after each job, we also know that the
                    # previous job was successful
                    mark_dispatched_to_dlq(skippable_message)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

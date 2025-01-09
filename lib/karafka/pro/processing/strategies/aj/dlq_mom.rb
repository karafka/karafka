# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # DLQ enabled
          # Manual offset management enabled
          #
          # AJ has manual offset management on by default and the offset management is delegated to
          # the AJ consumer. This means, we cannot mark as consumed always. We can only mark as
          # consumed when we skip given job upon errors. In all the other scenarios marking as
          # consumed needs to happen in the AJ consumer on a per job basis.
          module DlqMom
            include Strategies::Dlq::Mom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              manual_offset_management
            ].freeze

            # How should we post-finalize consumption.
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  # Do NOT commit offsets, they are comitted after each job in the AJ consumer.
                  coordinator.pause_tracker.reset
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

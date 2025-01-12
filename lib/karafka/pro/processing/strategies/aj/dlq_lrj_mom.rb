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
          # Long-Running Job enabled
          # Manual offset management enabled
          #
          # This case is a bit of special. Please see the `AjDlqMom` for explanation on how the
          # offset management works in this case.
          module DlqLrjMom
            include Strategies::Default
            include Strategies::Dlq::Default
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              long_running_job
              manual_offset_management
            ].freeze

            # We cannot use a VP version of this, because non-VP can early stop on shutdown
            def handle_after_consume
              coordinator.on_finished do
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # no need to check for manual seek because AJ consumer is internal and
                  # fully controlled by us
                  seek(seek_offset, false) unless revoked?

                  resume
                else
                  apply_dlq_flow do
                    skippable_message, = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
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

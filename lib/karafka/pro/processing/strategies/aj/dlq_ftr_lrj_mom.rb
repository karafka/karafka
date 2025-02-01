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
          # Filtering enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          module DlqFtrLrjMom
            include Strategies::Aj::FtrMom
            include Strategies::Aj::DlqMom
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              filtering
              long_running_job
              manual_offset_management
            ].freeze

            # This strategy assumes we do not early break on shutdown as it has VP
            def handle_after_consume
              coordinator.on_finished do
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked?
                    # no need to check for manual seek because AJ consumer is internal and
                    # fully controlled by us
                    seek(seek_offset, false, reset_offset: false)
                    resume
                  else
                    resume
                  end
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

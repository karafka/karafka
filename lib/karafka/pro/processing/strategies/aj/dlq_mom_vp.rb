# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module DlqMomVp
            include Strategies::Default
            include Strategies::Dlq::Vp
            include Strategies::Vp::Default

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              manual_offset_management
              virtual_partitions
            ].freeze

            # Flow including moving to DLQ in the collapsed mode
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # When this is an ActiveJob running via Pro with virtual partitions, we cannot
                  # mark intermediate jobs as processed not to mess up with the ordering.
                  # Only when all the jobs are processed and we did not loose the partition
                  # assignment and we are not stopping (Pro ActiveJob has an early break) we can
                  # commit offsets .
                  # For a non virtual partitions case, the flow is regular and state is marked
                  # after each successfully processed job
                  return if revoked?

                  mark_as_consumed(last_group_message)
                else
                  apply_dlq_flow do
                    # Here we are in a collapsed state, hence we can apply the same logic as
                    # Aj::DlqMom
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

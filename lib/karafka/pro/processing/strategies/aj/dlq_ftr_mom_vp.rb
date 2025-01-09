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
          # - VP
          module DlqFtrMomVp
            include Strategies::Aj::DlqMomVp
            include Strategies::Aj::DlqFtrMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ VP does not early stop on shutdown, hence here we can mark as consumed at the
            # end of all VPs
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
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

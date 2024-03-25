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
        module Aj
          # ActiveJob enabled
          # DLQ enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          #
          # This case is a bit of special. Please see the `Aj::DlqMom` for explanation on how the
          # offset management works in this case.
          module DlqLrjMomVp
            include Strategies::Aj::DlqMomVp
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            # This strategy assumes we do not early break on shutdown as it has VP
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Since we have VP here we do not commit intermediate offsets and need to commit
                  # them here. We do commit in collapsed mode but this is generalized.
                  mark_as_consumed(last_group_message) unless revoked?
                  # no need to check for manual seek because AJ consumer is internal and
                  # fully controlled by us
                  seek(coordinator.seek_offset, false) unless revoked?

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

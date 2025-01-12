# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module LrjMomVp
            include Strategies::Default
            include Strategies::Vp::Default

            # Features for this strategy
            FEATURES = %i[
              active_job
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            # No actions needed for the standard flow here
            def handle_before_schedule_consume
              super

              coordinator.on_enqueued do
                pause(:consecutive, Strategies::Lrj::Default::MAX_PAUSE_TIME, false)
              end
            end

            # Standard flow without any features
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  mark_as_consumed(last_group_message) unless revoked?

                  # no need to check for manual seek because AJ consumer is internal and
                  # fully controlled by us
                  seek(seek_offset, false) unless revoked?

                  resume
                else
                  # If processing failed, we need to pause
                  # For long running job this will overwrite the default never-ending pause and
                  # will cause the processing to keep going after the error backoff
                  retry_after_pause
                end
              end
            end

            # LRJ cannot resume here. Only in handling the after consumption
            def handle_revoked
              coordinator.on_revoked do
                coordinator.revoke
              end

              monitor.instrument('consumer.revoke', caller: self)
              monitor.instrument('consumer.revoked', caller: self) do
                revoked
              end
            ensure
              coordinator.decrement(:revoked)
            end
          end
        end
      end
    end
  end
end

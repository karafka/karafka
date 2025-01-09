# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for all the LRJ starting strategies
        module Lrj
          # Long-Running Job enabled
          # Manual offset management enabled
          module Mom
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              long_running_job
              manual_offset_management
            ].freeze

            # We always need to pause prior to doing any jobs for LRJ
            def handle_before_schedule_consume
              super

              # This ensures that when running LRJ with VP, things operate as expected run only
              # once for all the virtual partitions collectively
              coordinator.on_enqueued do
                pause(:consecutive, Strategies::Lrj::Default::MAX_PAUSE_TIME, false)
              end
            end

            # No offset management, aside from that typical LRJ
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  unless revoked? || coordinator.manual_seek?
                    seek(last_group_message.offset + 1, false)
                  end

                  resume
                else
                  retry_after_pause
                end
              end
            end

            # We do not un-pause on revokations for LRJ
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

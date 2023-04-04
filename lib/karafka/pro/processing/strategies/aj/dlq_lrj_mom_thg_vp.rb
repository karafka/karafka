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
          # Throttling enabled
          # Virtual Partitions enabled
          module DlqLrjMomThgVp
            include Strategies::Aj::MomThg
            include Strategies::Aj::DlqMomVp
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              long_running_job
              manual_offset_management
              throttling
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

                  if coordinator.throttled? && !revoked?
                    throttle_message = coordinator.throttler.message
                    throttle_timeout = coordinator.throttler.timeout

                    if coordinator.throttler.expired?
                      seek(throttle_message.offset)
                      resume
                    else
                      Karafka.monitor.instrument(
                        'throttling.throttled',
                        caller: self,
                        message: throttle_message,
                        timeout: throttle_timeout
                      )

                      pause(throttle_message.offset, throttle_timeout, false)
                    end
                  elsif !revoked?
                    seek(coordinator.seek_offset)
                    resume
                  else
                    resume
                  end
                elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                  retry_after_pause
                else
                  coordinator.pause_tracker.reset
                  skippable_message, = find_skippable_message
                  dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                  mark_as_consumed(skippable_message)
                  pause(coordinator.seek_offset, nil, false)
                end
              end
            end
          end
        end
      end
    end
  end
end

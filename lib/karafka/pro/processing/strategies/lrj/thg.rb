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
        module Lrj
          # Long-Running Job enabled
          # Throttling enabled
          #
          # In general aside from throttling this one will behave the same way as the Lrj
          module Thg
            include Strategies::Thg::Default
            include Strategies::Lrj::Default

            # Features for this strategy
            FEATURES = %i[
              long_running_job
              throttling
            ].freeze

            # LRJ standard flow after consumption with potential throttling on success
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Manual pausing has the highest priority
                  return if coordinator.manual_pause?

                  # It's not a MoM, so for successful we need to mark as consumed
                  mark_as_consumed(last_group_message) unless revoked?

                  # If still not revoked and was throttled, we need to apply throttling logic
                  if coordinator.throttled? && !revoked?
                    throttle_message = coordinator.throttler.message
                    throttle_timeout = coordinator.throttler.timeout

                    # We can just seek and removed if we've passed the expiration
                    # We need to resume because LRJ by default is paused
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

                      # Our throttle takes precedence over the never-ending LRJ pause
                      pause(throttle_message.offset, throttle_timeout, false)
                    end
                  elsif !revoked?
                    # If not revoked and not throttled, we move to where we were suppose to and
                    # resume
                    seek(coordinator.seek_offset)
                    resume
                  else
                    resume
                  end
                else
                  # If processing failed, we need to pause
                  # For long running job this will overwrite the default never-ending pause and
                  # will cause the processing to keep going after the error backoff
                  retry_after_pause
                end
              end
            end
          end
        end
      end
    end
  end
end

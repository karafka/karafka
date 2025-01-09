# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Lrj
          # Long-Running Job enabled
          # Filtering enabled
          # Manual offset management enabled
          #
          # It is really similar to the Lrj::Ftr but we do not mark anything as consumed
          module FtrMom
            include Strategies::Lrj::Ftr

            # Features for this strategy
            FEATURES = %i[
              filtering
              long_running_job
              manual_offset_management
            ].freeze

            # LRJ standard flow after consumption with potential filtering on success
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Manual pausing has the highest priority
                  return if coordinator.manual_pause?

                  # If still not revoked and was throttled, we need to apply filtering logic
                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked? && !coordinator.manual_seek?
                    # If not revoked and not throttled, we move to where we were suppose to and
                    # resume
                    seek(last_group_message.offset + 1, false)
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

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
        # ActiveJob enabled
        # Long-Running Job enabled
        # Manual offset management enabled
        module AjLrjMom
          # Features for this strategy
          FEATURES = %i[
            active_job
            long_running_job
            manual_offset_management
          ].freeze

          # Pauses polling data from a given partition
          def handle_before_enqueue
            # This ensures that when running LRJ with VP, things operate as expected run only once
            # for all the virtual partitions collectively
            coordinator.on_enqueued do
              # Pause at the first message in a batch. That way in case of a crash, we will not
              # loose any messages.
              #
              # For VP it applies the same way and since VP cannot be used with MOM we should not
              # have any edge cases here.
              pause(coordinator.seek_offset, Lrj::MAX_PAUSE_TIME)
            end
          end

          # Resume if all good, otherwise pause
          def handle_after_consume
            coordinator.on_finished do
              if coordinator.success?
                coordinator.pause_tracker.reset

                seek(coordinator.seek_offset) unless revoked?

                resume
              else
                pause(coordinator.seek_offset)
              end
            end
          end

          # Do not resume here as it's a LRJ variant
          def handle_revoked
            coordinator.on_revoked do
              coordinator.revoke
            end
          end
        end
      end
    end
  end
end

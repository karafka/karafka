# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # ActiveJob enabled
        # Long-Running Job enabled
        # Manual offset management enabled
        # Virtual Partitions enabled
        module AjLrjMomVp
          include Base

          # Features for this strategy
          FEATURES = %i[
            active_job
            long_running_job
            manual_offset_management
            virtual_partitions
          ].freeze

          # No actions needed for the standard flow here
          def handle_before_enqueue
            coordinator.on_enqueued do
              pause(coordinator.seek_offset, Lrj::MAX_PAUSE_TIME)
            end
          end

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              if coordinator.success?
                coordinator.pause_tracker.reset

                mark_as_consumed(last_group_message) unless revoked? || Karafka::App.stopping?
                seek(coordinator.seek_offset) unless revoked?

                resume
              else
                # If processing failed, we need to pause
                # For long running job this will overwrite the default never-ending pause and will cause
                # the processing to keep going after the error backoff
                pause(coordinator.seek_offset)
              end
            end
          end

          # LRJ cannot resume here. Only in handling the after consumption
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

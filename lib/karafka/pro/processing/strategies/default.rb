# frozen_string_literal: true

module Karafka
  module Pro
    module Processing
      module Strategies
        # No features enabled.
        # No manual offset management
        # No long running jobs
        # No virtual partitions
        # Nothing. Just standard, automatic flow
        module Default
          include Base

          # Apply strategy for a non-feature based flow
          FEATURES = %i[].freeze

          # No actions needed for the standard flow here
          def handle_before_enqueue
            nil
          end

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset

                mark_as_consumed(last_group_message)
              else
                pause(coordinator.seek_offset)
              end
            end
          end

          # Standard
          def handle_revoked
            coordinator.on_revoked do
              resume

              coordinator.revoke
            end
          end
        end
      end
    end
  end
end

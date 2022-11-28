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
        # No features enabled.
        # No manual offset management
        # No long running jobs
        # No virtual partitions
        # Nothing. Just standard, automatic flow
        module Default
          include Base
          include ::Karafka::Processing::Strategies::Default

          # Apply strategy for a non-feature based flow
          FEATURES = %i[].freeze

          # No actions needed for the standard flow here
          def handle_before_enqueue
            nil
          end

          # Increment number of attempts per one "full" job. For all VP on a single topic partition
          # this also should run once.
          def handle_before_consume
            coordinator.on_started do
              coordinator.pause_tracker.increment
            end
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

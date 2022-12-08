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
        # Manual offset management enabled
        # Virtual Partitions enabled
        module AjMomVp
          include Default

          # Features for this strategy
          FEATURES = %i[
            active_job
            manual_offset_management
            virtual_partitions
          ].freeze

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              if coordinator.success?
                coordinator.pause_tracker.reset

                # When this is an ActiveJob running via Pro with virtual partitions, we cannot mark
                # intermediate jobs as processed not to mess up with the ordering.
                # Only when all the jobs are processed and we did not loose the partition
                # assignment and we are not stopping (Pro ActiveJob has an early break) we can
                # commit offsets on this as only then we can be sure, that all the jobs were
                # processed.
                # For a non virtual partitions case, the flow is regular and state is marked after
                # each successfully processed job
                return if revoked?
                return if Karafka::App.stopping?

                mark_as_consumed(last_group_message)
              else
                retry_after_pause
              end
            end
          end
        end
      end
    end
  end
end

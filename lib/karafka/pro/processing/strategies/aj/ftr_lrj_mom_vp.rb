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
          # Filtering enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module FtrLrjMomVp
            include Strategies::Vp::Default
            include Strategies::Lrj::FtrMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ MOM VP does not do intermediate marking, hence we need to make sure we mark as
            # consumed here.
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  mark_as_consumed(last_group_message) unless revoked?

                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked?
                    # no need to check for manual seek because AJ consumer is internal and
                    # fully controlled by us
                    seek(coordinator.seek_offset, false)
                    resume
                  else
                    resume
                  end
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
end

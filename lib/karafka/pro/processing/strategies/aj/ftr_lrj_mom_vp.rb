# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
                    seek(seek_offset, false, reset_offset: false)
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

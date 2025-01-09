# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for ActiveJob related strategies
        module Aj
          # ActiveJob enabled
          # Filtering enabled
          # Manual Offset management enabled
          # Virtual partitions enabled
          module FtrMomVp
            include Strategies::Aj::FtrMom
            include Strategies::Aj::MomVp

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ with VPs always has intermediate marking disabled, hence we need to do it post
            # execution always.
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if revoked?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
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

# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Aj
          # ActiveJob enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module MomVp
            include Strategies::Default
            include Strategies::Vp::Default

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

                  return if revoked?

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
end

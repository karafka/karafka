# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Mom
          # Filtering support for MoM
          module Ftr
            include Strategies::Ftr::Default
            include Strategies::Mom::Default

            # MoM + Ftr
            FEATURES = %i[
              filtering
              manual_offset_management
            ].freeze

            # When mom is enabled, we do not mark messages as consumed after processing
            # but we also need to keep in mind throttling here
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Do not throttle if paused
                  return if coordinator.manual_pause?

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

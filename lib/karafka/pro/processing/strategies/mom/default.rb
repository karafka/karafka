# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Namespace for Mom starting strategies
        module Mom
          # Manual offset management enabled
          module Default
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              manual_offset_management
            ].freeze

            # When mom is enabled, we do not mark messages as consumed after processing
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset
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

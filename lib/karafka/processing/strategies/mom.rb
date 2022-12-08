# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # When using manual offset management, we do not mark as consumed after successful processing
      module Mom
        include Default

        # Apply strategy when only manual offset management is turned on
        FEATURES = %i[
          manual_offset_management
        ].freeze

        # When manual offset management is on, we do not mark anything as consumed automatically
        # and we rely on the user to figure things out
        def handle_after_consume
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

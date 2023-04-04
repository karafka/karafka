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

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
        module Dlq
          # - DLQ
          # - Ftr
          # - Mom
          module FtrMom
            include Strategies::Ftr::Default
            include Strategies::Dlq::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              manual_offset_management
            ].freeze

            # On mom we do not mark, throttling and seeking as in other strategies
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  handle_post_filtering
                elsif topic.dead_letter_queue.strategy.call(errors_tracker, attempt)
                  # We reset the pause to indicate we will now consider it as "ok".
                  coordinator.pause_tracker.reset

                  skippable_message, _marked = find_skippable_message
                  dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                  coordinator.seek_offset = skippable_message.offset + 1
                  pause(coordinator.seek_offset, nil, false)
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

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
          module Ftr
            include Strategies::Ftr::Default
            include Strategies::Dlq::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
            ].freeze

            # DLQ flow is standard here, what is not, is the success component where we need to
            # take into consideration the filtering
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(messages.last)

                  handle_post_filtering
                elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                  retry_after_pause
                else
                  coordinator.pause_tracker.reset
                  skippable_message, = find_skippable_message
                  dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                  mark_as_consumed(skippable_message)
                  pause(coordinator.seek_offset, nil, false)
                end
              end
            end
          end
        end
      end
    end
  end
end

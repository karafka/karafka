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
          # Strategy for supporting DLQ with Mom enabled
          module Mom
            # The broken message lookup is the same in this scenario
            include Strategies::Dlq::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              manual_offset_management
            ].freeze

            # When manual offset management is on, we do not mark anything as consumed
            # automatically and we rely on the user to figure things out
            def handle_after_consume
              coordinator.on_finished do
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset
                else
                  apply_dlq_flow do
                    skippable_message, = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                    if mark_after_dispatch?
                      mark_dispatched_to_dlq(skippable_message)
                    else
                      # Save the next offset we want to go with after moving given message to DLQ
                      # Without this, we would not be able to move forward and we would end up
                      # in an infinite loop trying to un-pause from the message we've already
                      # processed. Of course, since it's a MoM a rebalance or kill, will move it
                      # back as no offsets are being committed
                      coordinator.seek_offset = skippable_message.offset + 1
                    end
                  end
                end
              end
            end

            # @return [Boolean] should we mark given message as consumed after dispatch. For
            #  MOM strategies if user did not explicitly tell us to mark, we do not mark. Default
            #  is `nil`, which means `false` in this case. If user provided alternative value, we
            #  go with it.
            #
            # @note Please note, this is the opposite behavior than in case of AOM strategies.
            def mark_after_dispatch?
              return false if topic.dead_letter_queue.mark_after_dispatch.nil?

              topic.dead_letter_queue.mark_after_dispatch
            end
          end
        end
      end
    end
  end
end

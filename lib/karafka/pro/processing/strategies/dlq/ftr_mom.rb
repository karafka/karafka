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
                else
                  apply_dlq_flow do
                    skippable_message, _marked = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                    if mark_after_dispatch?
                      mark_dispatched_to_dlq(skippable_message)
                    else
                      coordinator.seek_offset = skippable_message.offset + 1
                    end
                  end
                end
              end
            end

            # @return [Boolean] should we mark given message as consumed after dispatch. For
            #  MOM strategies if user did not explicitly tell us to mark, we do not mark. Default is
            #  `nil`, which means `false` in this case. If user provided alternative value, we go
            #  with it.
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

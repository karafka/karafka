# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
              coordinator.on_finished do |last_group_message|
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
                else
                  apply_dlq_flow do
                    dispatch_if_needed_and_mark_as_consumed
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

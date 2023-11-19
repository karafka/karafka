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
        module Aj
          # ActiveJob enabled
          # DLQ enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          #
          # This case is a bit of special. Please see the `AjDlqMom` for explanation on how the
          # offset management works in this case.
          module DlqLrjMom
            include Strategies::Default
            include Strategies::Dlq::Default
            include Strategies::Aj::LrjMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              dead_letter_queue
              long_running_job
              manual_offset_management
            ].freeze

            # We cannot use a VP version of this, because non-VP can early stop on shutdown
            def handle_after_consume
              coordinator.on_finished do
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # no need to check for manual seek because AJ consumer is internal and
                  # fully controlled by us
                  seek(coordinator.seek_offset, false) unless revoked?

                  resume
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

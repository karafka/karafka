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
        # ActiveJob enabled
        # DLQ enabled
        # Manual offset management enabled
        #
        # AJ has manual offset management on by default and the offset management is delegated to
        # the AJ consumer. This means, we cannot mark as consumed always. We can only mark as
        # consumed when we skip given job upon errors. In all the other scenarios marking as
        # consumed needs to happen in the AJ consumer on a per job basis.
        module AjDlqMom
          include DlqMom

          # Features for this strategy
          FEATURES = %i[
            active_job
            dead_letter_queue
            manual_offset_management
          ].freeze

          # How should we post-finalize consumption.
          def handle_after_consume
            coordinator.on_finished do
              return if revoked?

              if coordinator.success?
                # Do NOT commit offsets, they are comitted after each job in the AJ consumer.
                coordinator.pause_tracker.reset
              elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                pause(coordinator.seek_offset, nil, false)
              else
                coordinator.pause_tracker.reset
                skippable_message = find_skippable_message
                dispatch_to_dlq(skippable_message) if dispatch_to_dlq?
                # We can commit the offset here because we know that we skip it "forever" and
                # since AJ consumer commits the offset after each job, we also know that the
                # previous job was successful
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

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
          # Dead-Letter Queue enabled
          # Filtering enabled
          # Long-Running Job enabled
          module FtrLrj
            include Strategies::Dlq::Lrj
            include Strategies::Lrj::Ftr

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              long_running_job
            ].freeze

            # This is one of more complex cases.
            # We need to ensure, that we always resume (inline or via paused backoff) and we need
            # to make sure we dispatch to DLQ when needed. Because revocation on LRJ can happen
            # any time, we need to make sure we do not dispatch to DLQ when error happens but we
            # no longer own the assignment. Throttling is another factor that has to be taken
            # into consideration on the successful path
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message) unless revoked?

                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked? && !coordinator.manual_seek?
                    seek(coordinator.seek_offset, false)
                    resume
                  else
                    resume
                  end
                elsif coordinator.pause_tracker.attempt <= topic.dead_letter_queue.max_retries
                  retry_after_pause
                else
                  coordinator.pause_tracker.reset

                  return resume if revoked?

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

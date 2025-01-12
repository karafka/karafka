# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
                    seek(seek_offset, false)
                    resume
                  else
                    resume
                  end
                else
                  apply_dlq_flow do
                    return resume if revoked?

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

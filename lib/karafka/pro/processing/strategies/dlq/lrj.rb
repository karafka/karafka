# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # DLQ enabled
          # Long-Running Job enabled
          module Lrj
            # Order here matters, lrj needs to be second
            include Strategies::Dlq::Default
            include Strategies::Lrj::Default

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              long_running_job
            ].freeze

            # LRJ standard flow after consumption with DLQ dispatch
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message) unless revoked?
                  # We should not overwrite user manual seel request with our seek
                  unless revoked? || coordinator.manual_seek?
                    seek(seek_offset, false, reset_offset: false)
                  end

                  resume
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

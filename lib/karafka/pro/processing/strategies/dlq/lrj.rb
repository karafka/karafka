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
                  seek(coordinator.seek_offset, false) unless revoked? || coordinator.manual_seek?

                  resume
                else
                  apply_dlq_flow do
                    coordinator.pause_tracker.reset

                    return resume if revoked?

                    dispatch_if_needed_and_mark_as_consumed

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
end

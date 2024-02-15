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
          # Strategy for supporting DLQ with Mom and LRJ enabled
          module LrjMom
            # This strategy needs to pause and revoke same way as DlqLrj but without the offset
            # management
            include Strategies::Dlq::Lrj

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              long_running_job
              manual_offset_management
            ].freeze

            # LRJ standard flow after consumption with DLQ dispatch and no offset management
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  unless revoked? || coordinator.manual_seek?
                    seek(last_group_message.offset + 1, false)
                  end

                  resume
                else
                  apply_dlq_flow do
                    coordinator.pause_tracker.reset

                    return resume if revoked?

                    skippable_message, _marked = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                    coordinator.seek_offset = skippable_message.offset + 1
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

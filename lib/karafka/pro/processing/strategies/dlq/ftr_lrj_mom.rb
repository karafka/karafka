# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        module Dlq
          # DLQ enabled
          # Ftr enabled
          # LRJ enabled
          # MoM enabled
          module FtrLrjMom
            include Strategies::Ftr::Default
            include Strategies::Dlq::LrjMom

            # Features for this strategy
            FEATURES = %i[
              dead_letter_queue
              filtering
              long_running_job
              manual_offset_management
            ].freeze

            # Post execution flow of this strategy
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if coordinator.manual_pause?

                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked? && !coordinator.manual_seek?
                    seek(last_group_message.offset + 1, false)
                    resume
                  else
                    resume
                  end
                else
                  apply_dlq_flow do
                    return resume if revoked?

                    skippable_message, _marked = find_skippable_message
                    dispatch_to_dlq(skippable_message) if dispatch_to_dlq?

                    if mark_after_dispatch?
                      mark_dispatched_to_dlq(skippable_message)
                    else
                      self.seek_offset = skippable_message.offset + 1
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
end

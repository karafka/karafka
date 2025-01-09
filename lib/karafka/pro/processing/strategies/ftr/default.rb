# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Strategies
        # Filtering related init strategies
        module Ftr
          # Only filtering enabled
          module Default
            include Strategies::Default

            # Just filtering enabled
            FEATURES = %i[
              filtering
            ].freeze

            # Empty run when running on idle means we need to filter
            def handle_idle
              handle_post_filtering
            end

            # Standard flow without any features
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                return if revoked?

                if coordinator.success?
                  coordinator.pause_tracker.reset

                  # Do not mark last message if pause happened. This prevents a scenario where
                  # pause is overridden upon rebalance by marking
                  return if coordinator.manual_pause?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
                else
                  retry_after_pause
                end
              end
            end

            # Throttles by pausing for an expected time period if throttling is needed or seeks
            # in case the throttle expired. Throttling may expire because we throttle before
            # processing starts and we need to compensate for processing time. It may turn out
            # that we don't have to pause but we need to move the offset because we skipped some
            # messages due to throttling filtering.
            # @return [Boolean] was any form of throttling operations (pause or seek) needed
            def handle_post_filtering
              filter = coordinator.filter

              # We pick the timeout before the action because every action takes time. This time
              # may then mean we end up having throttle time equal to zero when pause is needed
              # and this should not happen
              throttle_timeout = filter.timeout

              # If user requested marking when applying filter, we mark. We may be in the user
              # flow but even then this is not a problem. Older offsets will be ignored since
              # we do not force the offset update (expected) and newer are on the user to control.
              # This can be primarily used when filtering large quantities of data to mark on the
              # idle runs, so lag reporting is aware that those messages were not consumed but also
              # are no longer relevant
              if filter.mark_as_consumed?
                send(
                  filter.marking_method,
                  filter.cursor
                )
              end

              case filter.action
              when :skip
                nil
              when :seek
                # User direct actions take priority over automatic operations
                # If we've already seeked we can just resume operations, nothing extra needed
                return resume if coordinator.manual_seek?

                throttle_message = filter.cursor

                monitor.instrument(
                  'filtering.seek',
                  caller: self,
                  message: throttle_message
                ) do
                  seek(throttle_message.offset, false)
                end

                resume
              when :pause
                # User direct actions take priority over automatic operations
                return nil if coordinator.manual_pause?

                throttle_message = filter.cursor

                monitor.instrument(
                  'filtering.throttled',
                  caller: self,
                  message: throttle_message,
                  timeout: throttle_timeout
                ) do
                  pause(throttle_message.offset, throttle_timeout, false)
                end
              else
                raise Karafka::Errors::UnsupportedCaseError filter.action
              end
            end
          end
        end
      end
    end
  end
end

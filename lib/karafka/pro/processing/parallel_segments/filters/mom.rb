# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module ParallelSegments
        module Filters
          # Filter used for handling parallel segments when manual offset management (mom) is
          # enabled. Provides message distribution without any post-filtering offset state
          # management as it is fully user-based.
          #
          # Since with manual offset management we need to ensure that offsets are never marked
          # even in cases where all data in a batch is filtered out.
          #
          # This separation allows for cleaner implementation and easier debugging of each flow.
          #
          # @note This filter should be used only when manual offset management is enabled.
          #   For automatic offset management scenarios use the regular filter instead.
          class Mom < Base
            # Applies the filter to the batch of messages
            # It removes messages that don't belong to the current parallel segment group
            # based on the partitioner and reducer logic without any offset marking
            #
            # @param messages [Array<Karafka::Messages::Message>] messages batch that we want to
            #   filter
            def apply!(messages)
              @applied = false
              @cursor = messages.first unless messages.empty?

              # Filter out messages that don't match our segment group
              messages.delete_if do |message|
                message_group_key = @partitioner.call(message)
                # Use the reducer to get the target group for this message
                target_group = @reducer.call(message_group_key)
                # Remove the message if it doesn't belong to our group
                remove = target_group != @group_id

                if remove
                  @cursor = message
                  @applied = true
                end

                remove
              end
            end

            # @return [Boolean] true if any messages were filtered out
            def applied?
              @applied
            end

            # @return [Boolean] false, as mom mode never marks as consumed automatically
            def mark_as_consumed?
              false
            end

            # @return [Symbol] the marking method (never used in mom mode)
            def marking_method
              :mark_as_consumed
            end

            # @return [Symbol] the action to take (always skip for mom mode)
            def action
              :skip
            end

            # @return [Integer] timeout duration (not used for skip)
            def timeout
              0
            end
          end
        end
      end
    end
  end
end

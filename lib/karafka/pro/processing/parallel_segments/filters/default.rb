# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Processing components namespace for parallel segments feature
      module ParallelSegments
        module Filters
          # Filter used for handling parallel segments with automatic offset management. Handles
          # message distribution and ensures proper offset management when messages are filtered
          # out during the distribution process.
          #
          # When operating in automatic offset management mode, this filter takes care of marking
          # offsets of messages that were filtered out during the distribution process to maintain
          # proper offset progression.
          #
          # @note This is the default filter that should be used when manual offset management
          #   is not enabled. For manual offset management scenarios use the Mom filter instead.
          class Default < Base
            # Applies the filter to the batch of messages
            # It removes messages that don't belong to the current parallel segment group
            # based on the partitioner and reducer logic
            #
            # @param messages [Array<Karafka::Messages::Message>] messages batch that we want to
            #   filter
            def apply!(messages)
              @applied = false
              @all_filtered = false
              @cursor = messages.first unless messages.empty?

              # Keep track of how many messages we had initially
              initial_size = messages.size

              # Filter out messages that don't match our segment group
              messages.delete_if do |message|
                message_segment_key = @partitioner.call(message)

                # Use the reducer to get the target group for this message
                target_segment = @reducer.call(message_segment_key)

                # Remove the message if it doesn't belong to our group
                remove = target_segment != @segment_id

                if remove
                  @cursor = message
                  @applied = true
                end

                remove
              end

              # If all messages were filtered out, we want to mark them as consumed
              @all_filtered = messages.empty? && initial_size.positive?
            end

            # @return [Boolean] true if any messages were filtered out
            def applied?
              @applied
            end

            # @return [Boolean] true if we should mark as consumed (when all were filtered)
            def mark_as_consumed?
              @all_filtered
            end

            # @return [Symbol] the marking method to use
            def marking_method
              :mark_as_consumed
            end

            # @return [Symbol] the action to take (skip as we only mark)
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

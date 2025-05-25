# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Simple max value accumulator. When we dispatch messages we can store the max timestamp
      # until which messages were dispatched by us. This allows us to quickly skip those messages
      # during recovery, because we do know, they were dispatched.
      class MaxEpoch
        # We always give a bit of a buffer when using the max dispatch epoch because while we
        # are dispatching messages, we could also later receive data for time close to our
        # dispatch times. This is why when reloading days we give ourselves one hour of a window
        # that we will keep until tombstones expire them. This prevents edge cases race-conditions
        # when multiple scheduled events scheduled close to each other would bump epoch in such a
        # way, that it would end up ignoring certain events.
        GRACE_PERIOD = 60 * 60

        private_constant :GRACE_PERIOD

        # @return [Integer] max epoch recorded
        attr_reader :to_i

        def initialize
          @max = -1
          @to_i = @max
        end

        # Updates epoch if bigger than current max
        # @param new_max [Integer] potential new max epoch
        def update(new_max)
          return unless new_max > @max

          @max = new_max
          @to_i = @max - GRACE_PERIOD
        end
      end
    end
  end
end

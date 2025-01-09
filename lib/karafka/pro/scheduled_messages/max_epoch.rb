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
        def initialize
          @max = -1
        end

        # Updates epoch if bigger than current max
        # @param new_max [Integer] potential new max epoch
        def update(new_max)
          return unless new_max
          return unless new_max > @max

          @max = new_max
        end

        # @return [Integer] max epoch recorded
        def to_i
          @max
        end
      end
    end
  end
end

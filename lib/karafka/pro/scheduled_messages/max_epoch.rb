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

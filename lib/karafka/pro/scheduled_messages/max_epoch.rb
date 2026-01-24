# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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

        # Initializes max epoch tracker with -1 as starting value
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

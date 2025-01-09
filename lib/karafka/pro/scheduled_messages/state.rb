# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Represents the loading/bootstrapping state of the given topic partition
      #
      # Bootstrapping can be in the following states:
      # - fresh - when we got an assignment but we did not load the schedule yet
      # - loading - when we are in the process of bootstrapping the daily state and we consume
      #   historical messages to build the needed schedules.
      # - loaded - state in which we finished loading all the schedules and we can dispatch
      #   messages when the time comes and we can process real-time incoming schedules and
      #   changes to schedules as they appear in the stream.
      class State
        # @param loaded [nil, false, true] is the state loaded or not yet. `nil` indicates, it is
        #   a fresh, pre-seek state.
        def initialize(loaded = nil)
          @loaded = loaded
        end

        # @return [Boolean] are we in a fresh, pre-bootstrap state
        def fresh?
          @loaded.nil?
        end

        # Marks the current state as fully loaded
        def loaded!
          @loaded = true
        end

        # @return [Boolean] are we in a loaded state
        def loaded?
          @loaded == true
        end

        # @return [String] current state string representation
        def to_s
          case @loaded
          when nil
            'fresh'
          when false
            'loading'
          when true
            'loaded'
          end
        end
      end
    end
  end
end

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

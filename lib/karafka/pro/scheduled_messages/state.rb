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
      # - shutdown - the states are no longer available as the consumer has shut down
      class State
        # Available states scheduling of messages may be in
        STATES = %w[
          fresh
          loading
          loaded
          stopped
        ].freeze

        private_constant :STATES

        def initialize
          @state = 'fresh'
        end

        STATES.each do |state|
          define_method :"#{state}!" do
            @state = state
          end

          define_method :"#{state}?" do
            @state == state
          end
        end

        # @return [String] current state string representation
        def to_s
          @state
        end
      end
    end
  end
end

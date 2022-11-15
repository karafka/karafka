# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    # Available states and their transitions.
    STATES = {
      initializing: :initialize!,
      initialized: :initialized!,
      running: :run!,
      quieting: :quiet!,
      stopping: :stop!,
      stopped: :stopped!
    }.freeze

    private_constant :STATES

    # By default we are in the initializing state
    def initialize
      initialize!
    end

    STATES.each do |state, transition|
      define_method :"#{state}?" do
        @status == state
      end

      define_method transition do
        # Do nothing if the state change would change nothing (same state)
        return if @status == state

        @status = state

        # Skip on creation (initializing)
        # We skip as during this state we do not have yet a monitor
        return if initializing?

        Karafka.monitor.instrument("app.#{state}")
      end
    end
  end
end

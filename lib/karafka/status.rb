# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    # Available states and their transitions.
    STATES = {
      initializing: :initialize!,
      initialized: :initialized!,
      running: :run!,
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
        @status = state

        # Skip on creation (initializing)
        # We skip as during this state we do not have yet a monitor
        return if initializing?

        # Trap context disallows to run certain things that we instrument
        # so the state changes are executed from a separate thread
        Thread.new { Karafka.monitor.instrument("app.#{state}") }.join
      end
    end
  end
end

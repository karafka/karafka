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
      stopped: :stopped!,
      terminated: :terminate!
    }.freeze

    # Mutex to ensure that state transitions are thread-safe
    MUTEX = Mutex.new

    private_constant :STATES, :MUTEX

    # By default we are in the initializing state
    def initialize
      initialize!
    end

    # Resets the status state
    # This is used mostly in the integration suite
    def reset!
      @status = :initializing
    end

    STATES.each do |state, transition|
      define_method :"#{state}?" do
        @status == state
      end

      define_method transition do
        MUTEX.synchronize do
          # Do not allow reverse state transitions (we always go one way) or transition to the same
          # state as currently
          return if @status && STATES.keys.index(state) <= STATES.keys.index(@status)

          @status = state

          # Skip on creation (initializing)
          # We skip as during this state we do not have yet a monitor
          return if initializing?

          Karafka.monitor.instrument("app.#{state}")
        end
      end
    end
  end
end

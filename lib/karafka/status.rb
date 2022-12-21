# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    # Available states and their transitions.
    STATES = {
      initializing: :initialize!,
      initialized: :initialized!,
      running: :run!,
      # will no longer pickup any work, but current work will be finished
      quieting: :quiet!,
      # no work is happening but we keep process with the assignments running
      quiet: :quieted!,
      # shutdown started
      stopping: :stop!,
      # all things are done and most of the things except critical are closed
      stopped: :stopped!,
      # immediately after this process exists
      terminated: :terminate!
    }.freeze

    # Mutex to ensure that state transitions are thread-safe
    MUTEX = Mutex.new

    private_constant :MUTEX

    # By default we are in the initializing state
    def initialize
      initialize!
    end

    # @return [String] stringified current app status
    def to_s
      @status.to_s
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

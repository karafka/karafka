# frozen_string_literal: true

module Karafka
  # App status monitor
  class Status
    include Helpers::ConfigImporter.new(
      monitor: %i[monitor],
      conductor: %i[internal connection conductor]
    )

    # Available states and their transitions.
    STATES = {
      initializing: :initialize!,
      initialized: :initialized!,
      supervising: :supervise!,
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
      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{state}?
          @status == :#{state}
        end

        def #{transition}
          MUTEX.synchronize do
            # Do not allow reverse state transitions (we always go one way) or transition to the
            # same state as currently
            return if @status && STATES.keys.index(:#{state}) <= STATES.keys.index(@status)

            @status = :#{state}

            # Skip on creation (initializing)
            # We skip as during this state we do not have yet a monitor
            return if initializing?

            conductor.signal

            monitor.instrument(
              "app.#{state}",
              caller: self,
              server_id: Karafka::Server.id
            )
          end
        end
      RUBY
    end

    # @return [Boolean] true if we are in any of the status that would indicate we should no longer
    #   process incoming data. It is a meta status built from others and not a separate state in
    #   the sense of a state machine
    def done?
      # Short-track for the most common case not to invoke all others on normal execution
      return false if running?
      return false if supervising?

      stopping? || stopped? || quieting? || quiet? || terminated?
    end
  end
end

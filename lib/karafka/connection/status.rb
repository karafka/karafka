# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # Listener connection status representation
    class Status
      include Helpers::ConfigImporter.new(
        monitor: %i[monitor],
        conductor: %i[internal connection conductor]
      )

      # Available states and their transitions.
      STATES = {
        pending: :pending!,
        starting: :start!,
        running: :running!,
        quieting: :quiet!,
        quiet: :quieted!,
        stopping: :stop!,
        stopped: :stopped!
      }.freeze

      STATES.each do |state, transition|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          # Moves status to a different state
          def #{transition}
            @mutex.synchronize do
              # Do not allow reverse state transitions (we always go one way) or transition to the
              # same state as currently
              return if @status && STATES.keys.index(:#{state}) <= STATES.keys.index(@status)

              @status = :#{state}
              conductor.signal
              monitor.instrument("connection.listener.#{state}", caller: self)
            end
          end

          # @return [Boolean] are we in a given state
          def #{state}?
            @status == :#{state}
          end
        RUBY
      end

      def initialize
        @mutex = Mutex.new
        pending!
      end

      # If this listener was not even running, will just move it through states until final.
      # If it was running, will start the stopping procedures.
      # Will do nothing if it was already stopped
      def stop!
        if pending?
          @status = :stopping
          conductor.signal
          monitor.instrument('connection.listener.stopping', caller: self)

          stopped!
        elsif stopped?
          nil
        elsif stopping?
          nil
        else
          @status = :stopping
          conductor.signal
          monitor.instrument('connection.listener.stopping', caller: self)
        end
      end

      # Moves status back from stopped to pending (and only that). We should not be able to reset
      # listeners that are not stopped
      def reset!
        return unless stopped?

        @status = :pending
      end

      # @return [Boolean] listener is considered active when it has a client reference that may
      #   be active and connected to Kafka
      def active?
        !pending? && !stopped?
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # Connections manager responsible for starting and managing listeners connections
    #
    # In the OSS version it starts listeners as they are without any connection management or
    # resources utilization supervision and shuts them down or quiets  when time has come
    class Manager
      def initialize
        @once_executions = Set.new
      end

      # Registers provided listeners and starts all of them
      #
      # @param listeners [Connection::ListenersBatch]
      def register(listeners)
        @listeners = listeners
        @listeners.each(&:start!)
      end

      # @return [Boolean] true if all listeners are stopped
      def done?
        @listeners.all?(&:stopped?)
      end

      # Controls the state of listeners upon shutdown and quiet requests
      # In both cases (quieting and shutdown) we first need to stop processing more work and tell
      # listeners to become quiet (connected but not yielding messages) and then depending on
      # whether we want to stop fully or just keep quiet we apply different flow.
      #
      # @note It is important to ensure, that all listeners from the same consumer group are always
      #   all quiet before we can fully shutdown given consumer group. Skipping this can cause
      #   `Timed out LeaveGroupRequest in flight` and other errors. For the simplification, we just
      #   quiet all and only then move forward.
      #
      # @note This manager works with the assumption, that all listeners are executed on register.
      def control
        # Do nothing until shutdown or quiet
        return unless Karafka::App.done?

        # When we are done processing, immediately quiet all the listeners so they do not pick up
        # new work to do
        once(:quiet!) { @listeners.each(&:quiet!) }

        return unless @listeners.all?(&:quiet?)

        # If we are in the process of moving to quiet state, we need to check it.
        # Switch to quieted status only when all listeners are fully quieted and do nothing after
        # that until further state changes
        once(:quieted!) { Karafka::App.quieted! } if Karafka::App.quieting?

        return if Karafka::App.quiet?

        once(:stop!) { @listeners.each(&:stop!) }
      end

      private

      # Runs code only once and never again
      # @param args [Object] anything we want to use as a set of unique keys for given execution
      def once(*args)
        return if @once_executions.include?(args)

        @once_executions << args

        yield
      end
    end
  end
end

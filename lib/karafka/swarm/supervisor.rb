# frozen_string_literal: true

module Karafka
  module Swarm
    # Supervisor that starts forks and uses monitor to monitor them. Also handles shutdown of
    # all the processes including itself.
    #
    # In case any node dies, it will be restarted.
    #
    # @note Technically speaking supervisor is never in the running state because we do not want
    #   to have any sockets or anything else on it that could break under forking.
    #   It has its own "supervising" state from which it can go to the final shutdown.
    class Supervisor
      include Karafka::Core::Helpers::Time
      include Helpers::ConfigImporter.new(
        monitor: %i[monitor],
        swarm: %i[internal swarm],
        manager: %i[internal swarm manager],
        supervision_interval: %i[internal swarm supervision_interval],
        shutdown_timeout: %i[shutdown_timeout],
        supervision_sleep: %i[internal supervision_sleep],
        forceful_exit_code: %i[internal forceful_exit_code],
        process: %i[internal process],
        cli_contract: %i[internal cli contract],
        activity_manager: %i[internal routing activity_manager]
      )

      # How long extra should we wait on shutdown before forceful termination
      # We add this time because we send signals and it always can take a bit of time for them
      # to reach out nodes and be processed to start the shutdown flow. Because of that and
      # because we always want to give all nodes all the time of `shutdown_timeout` they are
      # expected to have, we add this just to compensate.
      SHUTDOWN_GRACE_PERIOD = 1_000

      private_constant :SHUTDOWN_GRACE_PERIOD

      def initialize
        @mutex = Mutex.new
        @queue = Processing::TimedQueue.new
      end

      # Creates needed number of forks, installs signals and starts supervision
      def run
        # Validate the CLI provided options the same way as we do for the regular server
        cli_contract.validate!(activity_manager.to_h)

        # Close producer just in case. While it should not be used, we do not want even a
        # theoretical case since librdkafka is not thread-safe.
        # We close it prior to forking just to make sure, there is no issue with initialized
        # producer (should not be initialized but just in case)
        Karafka.producer.close

        Karafka::App.warmup

        manager.start

        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }
        process.on_sigtstp { quiet }
        process.on_sigttin { signal('TTIN') }
        # Needed to be registered as we want to unlock on child changes
        process.on_sigchld {}
        process.on_any_active { unlock }
        process.supervise

        Karafka::App.supervise!

        loop do
          return if Karafka::App.terminated?

          lock
          control
        end

      # If the cli contract validation failed reraise immediately and stop the process
      rescue Karafka::Errors::InvalidConfigurationError => e
        raise e
      # If anything went wrong during supervision, signal this and die
      # Supervisor is meant to be thin and not cause any issues. If you encounter this case
      # please report it as it should be considered critical
      rescue StandardError => e
        monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          manager: manager,
          type: 'swarm.supervisor.error'
        )

        manager.terminate
        manager.cleanup

        raise e
      end

      private

      # Keeps the lock on the queue so we control nodes only when it is needed
      # @note We convert to seconds since the queue timeout requires seconds
      def lock
        @queue.pop(timeout: supervision_interval / 1_000.0)
      end

      # Frees the lock on events that could require nodes control
      def unlock
        @queue << true
      end

      # Stops all the nodes and supervisor once all nodes are dead.
      # It will forcefully stop all nodes if they exit the shutdown timeout. While in theory each
      # of the nodes anyhow has its own supervisor, this is a last resort to stop everything.
      def stop
        # Ensure that the stopping procedure is initialized only once
        @mutex.synchronize do
          return if @stopping

          @stopping = true
        end

        initialized = true
        Karafka::App.stop!

        manager.stop

        total_shutdown_timeout = shutdown_timeout + SHUTDOWN_GRACE_PERIOD

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        # We divide it by 1000 because we use time in ms.
        ((total_shutdown_timeout / 1_000) * (1 / supervision_sleep)).to_i.times do
          if manager.stopped?
            manager.cleanup
            return
          end

          sleep(supervision_sleep)
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          manager: manager,
          type: 'app.stopping.error'
        )

        # Run forceful kill
        manager.terminate
        # And wait until linux kills them
        # This prevents us from existing forcefully with any dead child process still existing
        # Since we have sent the `KILL` signal, it must die, so we can wait until all dead
        sleep(supervision_sleep) until manager.stopped?

        # Cleanup the process table
        manager.cleanup

        # We do not use `exit!` here similar to regular server because we do not have to worry
        # about any librdkafka related hanging connections, etc
        Kernel.exit(forceful_exit_code)
      ensure
        if initialized
          Karafka::App.stopped!
          Karafka::App.terminate!
        end
      end

      # Moves all the nodes and itself to the quiet state
      def quiet
        @mutex.synchronize do
          return if @quieting

          @quieting = true

          Karafka::App.quiet!
          manager.quiet
          Karafka::App.quieted!
        end
      end

      # Checks on the children nodes and takes appropriate actions.
      # - If node is dead, will cleanup
      # - If node is no longer reporting as healthy will start a graceful shutdown
      # - If node does not want to close itself gracefully, will kill it
      # - If node was dead, new node will be started as a recovery means
      def control
        @mutex.synchronize do
          # If we are in quieting or stopping we should no longer control children
          # Those states aim to finally shutdown nodes and we should not forcefully do anything
          # to them. This especially applies to the quieting mode where any complex lifecycle
          # reporting listeners may no longer report correctly
          return if @quieting
          return if @stopping

          manager.control
        end
      end

      # Sends desired signal to each node
      # @param signal [String]
      def signal(signal)
        @mutex.synchronize do
          manager.signal(signal)
        end
      end
    end
  end
end

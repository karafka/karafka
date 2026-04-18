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
      #
      # Beyond signal propagation, child nodes also need a window after their own graceful
      # `shutdown_timeout` to actually exit the process (run `at_exit` handlers, finalize
      # librdkafka handles, close pools, etc.). On CI (especially macOS) the effective loop
      # duration is noticeably longer than the nominal budget because `sleep` granularity and
      # the per-iteration `waitpid` cost stretch each 0.1s tick. A too-tight grace period
      # causes the supervisor to raise `ForcefulShutdownError` while a node is still in its
      # final cleanup phase, which manifests as flaky shutdowns in swarm integration tests.
      SHUTDOWN_GRACE_PERIOD = 15_000

      private_constant :SHUTDOWN_GRACE_PERIOD

      # Initializes the swarm supervisor
      def initialize
        @mutex = Mutex.new
        @queue = Queue.new
      end

      # Creates needed number of forks, installs signals and starts supervision
      def run
        # Validate the CLI provided options the same way as we do for the regular server
        cli_contract.validate!(
          activity_manager.to_h,
          scope: %w[swarm cli]
        )

        # Close producer just in case. While it should not be used, we do not want even a
        # theoretical case since librdkafka is not thread-safe.
        # We close it prior to forking just to make sure, there is no issue with initialized
        # producer (should not be initialized but just in case)
        Karafka.producer.close

        # Ensure rdkafka stuff is loaded into memory pre-fork. This will ensure, that we save
        # few MB on forking as this will be already in memory.
        Rdkafka::Bindings.rd_kafka_global_init

        Karafka::App.warmup

        manager.start

        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }
        process.on_sigtstp { quiet }
        process.on_sigttin { signal("TTIN") }
        # Needed to be registered as we want to unlock on child changes
        process.on_sigchld { nil }
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
      rescue => e
        monitor.instrument(
          "error.occurred",
          caller: self,
          error: e,
          manager: manager,
          type: "swarm.supervisor.error"
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

        $stderr.puts "[SWARM_DEBUG] stop method entered, thread=#{Thread.current.object_id} " \
          "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
        $stderr.flush

        initialized = true
        Karafka::App.stop!

        manager.stop

        total_shutdown_timeout = shutdown_timeout + SHUTDOWN_GRACE_PERIOD
        total_iterations = ((total_shutdown_timeout / 1_000) * (1 / supervision_sleep)).to_i

        # DEBUG: log all timing parameters
        loop_start = monotonic_now
        wall_start = Time.now
        $stderr.puts "[SWARM_DEBUG] stop loop starting: " \
          "shutdown_timeout=#{shutdown_timeout} " \
          "grace=#{SHUTDOWN_GRACE_PERIOD} " \
          "total_timeout=#{total_shutdown_timeout}ms " \
          "supervision_sleep=#{supervision_sleep} " \
          "iterations=#{total_iterations} " \
          "thread=#{Thread.current.object_id} " \
          "wall=#{wall_start.strftime('%H:%M:%S.%L')} " \
          "nodes=#{manager.nodes.map { |n| "#{n.id}:pid=#{n.pid}" }.join(',')}"
        $stderr.flush

        iteration = 0
        last_report = loop_start

        total_iterations.times do
          iteration += 1
          iter_start = monotonic_now

          stopped = manager.stopped?

          if stopped
            elapsed = monotonic_now - loop_start
            $stderr.puts "[SWARM_DEBUG] manager.stopped?=true at iteration #{iteration}/#{total_iterations}, " \
              "elapsed=#{elapsed.round(1)}ms (#{(elapsed / 1_000).round(2)}s), " \
              "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            $stderr.flush
            manager.cleanup
            return
          end

          slept_start = monotonic_now
          sleep(supervision_sleep)
          slept_end = monotonic_now

          now = monotonic_now
          # Report every 5 seconds or on first/last iterations
          if (now - last_report) >= 5_000 || iteration == 1 || iteration == total_iterations
            elapsed = now - loop_start
            alive_detail = manager.nodes.map do |n|
              "#{n.id}:alive=#{n.alive?}:pid=#{n.pid}"
            end.join(",")
            $stderr.puts "[SWARM_DEBUG] iteration #{iteration}/#{total_iterations} " \
              "elapsed=#{elapsed.round(1)}ms (#{(elapsed / 1_000).round(2)}s) " \
              "stopped_check=#{(slept_start - iter_start).round(2)}ms " \
              "sleep_actual=#{(slept_end - slept_start).round(2)}ms " \
              "iter_total=#{(now - iter_start).round(2)}ms " \
              "nodes=[#{alive_detail}] " \
              "wall=#{Time.now.strftime('%H:%M:%S.%L')}"
            $stderr.flush
            last_report = now
          end
        end

        final_elapsed = monotonic_now - loop_start
        $stderr.puts "[SWARM_DEBUG] TIMEOUT: loop exhausted #{total_iterations} iterations in " \
          "#{final_elapsed.round(1)}ms (#{(final_elapsed / 1_000).round(2)}s), " \
          "wall_start=#{wall_start.strftime('%H:%M:%S.%L')} " \
          "wall_end=#{Time.now.strftime('%H:%M:%S.%L')} " \
          "raising ForcefulShutdownError"
        $stderr.flush

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        monitor.instrument(
          "error.occurred",
          caller: self,
          error: e,
          manager: manager,
          active_listeners: [],
          alive_workers: [],
          in_processing: {},
          type: "app.stopping.error"
        )

        # Run forceful kill
        $stderr.puts "[SWARM_DEBUG] sending SIGKILL to all nodes"
        $stderr.flush
        manager.terminate

        kill_wait_start = monotonic_now
        kill_iters = 0
        until manager.stopped?
          kill_iters += 1
          sleep(supervision_sleep)
          if kill_iters % 10 == 0
            $stderr.puts "[SWARM_DEBUG] post-SIGKILL wait: #{kill_iters} iterations, " \
              "elapsed=#{(monotonic_now - kill_wait_start).round(1)}ms"
            $stderr.flush
          end
        end
        $stderr.puts "[SWARM_DEBUG] post-SIGKILL stopped after #{kill_iters} iterations, " \
          "#{(monotonic_now - kill_wait_start).round(1)}ms"
        $stderr.flush

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

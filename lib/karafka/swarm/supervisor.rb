# frozen_string_literal: true

module Karafka
  module Swarm
    # Supervisor that starts forks and monitors them to check if they are ok.
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
        nodes_count: %i[swarm nodes],
        swarm: %i[internal swarm],
        supervision_interval: %i[internal swarm supervision_interval],
        shutdown_timeout: %i[shutdown_timeout],
        supervision_sleep: %i[internal supervision_sleep],
        forceful_exit_code: %i[internal forceful_exit_code],
        process: %i[internal process],
        node_report_timeout: %i[internal swarm node_report_timeout]
      )

      def initialize
        @mutex = Mutex.new
        @nodes = []
        @queue = Processing::TimedQueue.new
        @nodes_statuses = Hash.new { |h, k| h[k] = {} }
      end

      # Creates needed number of forks, installs signals and starts supervision
      def run
        pidfd = Pidfd.new(::Process.pid)

        monitor.instrument('swarm.supervisor.before_fork', caller: self, nodes: @nodes)

        @nodes = Array.new(nodes_count) do |i|
          Node.new(i, pidfd).tap(&:start)
        end

        monitor.instrument('swarm.supervisor.after_fork', caller: self, nodes: @nodes)

        @nodes.each { |node| @nodes_statuses[node][:control] = monotonic_now }

        # Close producer just in case. While it should not be used, we do not want even a
        # theoretical case since librdkafka is not thread-safe.
        Karafka.producer.close

        # Indicate this is not a swarm node
        swarm.node = false

        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }
        process.on_sigtstp { quiet }
        process.on_any_active { unlock }
        process.supervise

        Karafka::App.supervise!

        loop do
          return if Karafka::App.terminated?

          lock
          control
        end
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

        @nodes.each(&:stop)

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        # We divide it by 1000 because we use time in ms.
        ((shutdown_timeout / 1_000) * (1 / supervision_sleep)).to_i.times do
          return if @nodes.none?(&:alive?)

          sleep(supervision_sleep)
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          nodes: @nodes,
          type: 'app.stopping.error'
        )

        @nodes.each(&:terminate)

        # exit! is not within the instrumentation as it would not trigger due to exit
        Kernel.exit!(forceful_exit_code)
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
          @nodes.each(&:quiet)
          Karafka::App.quieted!
        end
      end

      # Checks on the children nodes and takes appropriate actions.
      # - If node is dead, will cleanup
      # - If node is no longer reporting as healthy will start a graceful shutdown
      # - If node does not want to close itself gracefully, will kill it
      # - If node was dead, new node will be started as a recovery means
      def control
        # tutaj backoff zeby to nie lecialo czesciej niz raz na 10 sekund niezaleznie od tickow
        @mutex.synchronize do
          # If we are in quieting or stopping we should no longer control children
          # Those states aim to finally shutdown nodes and we should not forcefully do anything
          # to them.
          return if @quieting
          return if @stopping

          monitor.instrument('swarm.supervisor.control', caller: self, nodes: @nodes)

          @nodes.each do |node|
            if node.alive?
              statuses = @nodes_statuses[node]

              if statuses.key?(:stop)
                next unless monotonic_now - statuses[:stop] >= shutdown_timeout

                monitor.instrument('swarm.supervisor.terminating', caller: self, nodes: @nodes, node: node) do
                  node.terminate
                end
              end

              report = node.read

              if report
                statuses[:control] = monotonic_now

                if report.include?('0')
                  monitor.instrument('swarm.supervisor.stopping', caller: self, nodes: @nodes, node: node) do
                    node.stop
                    statuses[:stop] = monotonic_now
                  end
                end
              end

              if monotonic_now - statuses[:control] >= node_report_timeout
                monitor.instrument('swarm.supervisor.stopping', caller: self, nodes: @nodes, node: node) do
                  node.stop
                  statuses[:stop] = monotonic_now
                end
              end
            else
              node.cleanup
              @nodes_statuses[node] = {}
              @nodes_statuses[node][:control] = monotonic_now

              monitor.instrument('swarm.supervisor.before_fork', caller: self, nodes: @nodes, node: node)
              node.start
              monitor.instrument('swarm.supervisor.after_fork', caller: self, nodes: @nodes, node: node)
            end
          end
        end
      end
    end
  end
end

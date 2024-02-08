# frozen_string_literal: true

module Karafka
  module Swarm
    # Supervisor that starts forks and monitors them to check if they are ok.
    #
    # In case any dies, it will be restarted.
    #
    # @note Technically speaking supervisor is never in the running state because we do not want
    #   to have any sockets or anything else on it that could break under forking
    class Supervisor
      include Karafka::Core::Helpers::Time
      include Helpers::Imports::Monitor
      include Helpers::Imports::Config.new(
        swarm_config: %i[internal swarm],
        supervision_interval: %i[internal swarm supervision_interval],
        shutdown_timeout: %i[shutdown_timeout],
        supervision_sleep: %i[internal supervision_sleep],
        forceful_exit_code: %i[forceful_exit_code],
        process: %i[internal process]
      )

      def initialize
        @mutex = Mutex.new
        @nodes = []
        @nodes_statuses = Hash.new { |h, k| h[k] = {} }
        @queue = Processing::TimedQueue.new
      end

      def run
        monitor.instrument('swarm.supervisor.before_fork', caller: self)

        @pidfd = Pidfd.new(::Process.pid)

        @nodes = Array.new(3) do |i|
          Node.new(i, @pidfd).tap(&:start)
        end

        @nodes.each { |node| @nodes_statuses[node][:control] = monotonic_now }

        Karafka.producer.close
        swarm_config.node = false

        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }
        process.on_sigtstp { quiet }
        process.on_any_active { unlock }
        process.supervise

        Karafka::App.supervise!

        while true
          return if Karafka::App.terminated?

          lock
          control
        end
      end

      private

      def lock
        @queue.pop(timeout: supervision_interval / 1_000.0)
      end

      def unlock
        @queue << true
      end

      def stop
        return if swarm_config.node

        # Initialize the stopping process only if Karafka was running
        return if Karafka::App.stopping?
        return if Karafka::App.stopped?
        return if Karafka::App.terminated?

        Karafka::App.stop!

        @nodes.each(&:stop)

        timeout = shutdown_timeout

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        # We divide it by 1000 because we use time in ms.
        ((timeout / 1_000) * (1 / supervision_sleep)).to_i.times do
          return if @nodes.none?(&:alive?)

          sleep(supervision_sleep)
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          type: 'app.stopping.error'
        )

        @nodes.each(&:terminate)

        # exit! is not within the instrumentation as it would not trigger due to exit
        Kernel.exit!(forceful_exit_code)
      ensure
        if timeout
          Karafka::App.stopped!
          Karafka::App.producer.close
          Karafka::App.terminate!
        end
      end

      def quiet
        return if swarm_config.node

        Karafka::App.quiet!
        @nodes.each(&:quiet)
        Karafka::App.quieted!
      end

      def control
        # tutaj backoff zeby to nie lecialo czesciej niz raz na 10 sekund niezaleznie od tickow
        return if swarm_config.node

        @mutex.synchronize do
          return if Karafka::App.done?

          @nodes.each do |node|
            if node.alive?
              statuses = @nodes_statuses[node]

              if statuses.key?(:stop)
                node.terminate if monotonic_now - statuses[:stop] >= shutdown_timeout

                next
              end

              report = node.read

              if report
                statuses[:control] = monotonic_now
                if report.include?('0')
                  node.stop
                  statuses[:stop] = monotonic_now
                end
              end

              if monotonic_now - statuses[:control] >= 10_000
                node.stop
                statuses[:stop] = monotonic_now
              end
            else
              node.cleanup
              monitor.instrument('swarm.supervisor.before_fork', caller: self)
              node.start
              @nodes_statuses[node] = {}
              @nodes_statuses[node][:control] = monotonic_now
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Karafka consuming server class
  class Server
    # How long should we wait on the listeners forceful shutdown when they are stuck beyond the
    # shutdown timeout before forcing a bypass
    FORCEFUL_SHUTDOWN_WAIT = 5

    private_constant :FORCEFUL_SHUTDOWN_WAIT

    extend Helpers::ConfigImporter.new(
      cli_contract: %i[internal cli contract],
      activity_manager: %i[internal routing activity_manager],
      supervision_sleep: %i[internal supervision_sleep],
      shutdown_timeout: %i[shutdown_timeout],
      forceful_exit_code: %i[internal forceful_exit_code],
      process: %i[internal process]
    )

    class << self
      # Set of consuming threads. Each consumer thread contains a single consumer
      attr_accessor :listeners

      # Set of workers
      attr_accessor :workers

      # Jobs queue
      attr_accessor :jobs_queue

      # Mode in which the Karafka server is executed. It can be:
      #
      # - :standalone - regular karafka consumer process
      # - :embedded - embedded in a different process and not supervised
      # - :supervisor - swarm supervisor process
      # - :swarm - one of swarm processes
      #
      # Sometimes it is important to know in what mode we operate, especially from UI perspective
      # as not everything is possible when operating in non-standalone mode, etc.
      attr_accessor :execution_mode

      # id of the server. Useful for logging when we want to reference things issued by the server.
      attr_accessor :id

      # Method which runs app
      def run
        self.listeners = []
        self.workers = []

        # We need to validate this prior to running because it may be executed also from the
        # embedded
        # We cannot validate this during the start because config needs to be populated and routes
        # need to be defined.
        cli_contract.validate!(
          activity_manager.to_h,
          scope: %w[cli]
        )

        # We clear as we do not want parent handlers in case of working from fork
        process.clear
        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }
        process.on_sigtstp { quiet }
        # Needed for instrumentation
        process.on_sigttin {}
        process.supervise

        # This will only run when not in a swarm mode. In swarm mode the server runs post-fork, so
        # warmup will do nothing
        Karafka::App.warmup

        # Start is blocking until stop is called and when we stop, it will wait until
        # all of the things are ready to stop
        start

        # We always need to wait for Karafka to stop here since we should wait for the stop running
        # in a separate thread (or trap context) to indicate everything is closed
        # Since `#start` is blocking, we will get here only after the runner is done. This will
        # not add any performance degradation because of that.
        sleep(0.1) until Karafka::App.terminated?
      # Try its best to shutdown underlying components before re-raising
      # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        stop

        raise e
      end

      # Starts Karafka with a supervision
      # @note We don't need to sleep because Karafka::Runner is locking and waiting to finish loop
      # (and it won't happen until we explicitly want to stop)
      def start
        Karafka::Runner.new.call
      end

      # Stops Karafka with a supervision (as long as there is a shutdown timeout)
      # If consumers or workers won't stop in a given time frame, it will force them to exit
      #
      # @note This method is not async. It should not be executed from the workers as it will
      #   lock them forever. If you need to run Karafka shutdown from within workers threads,
      #   please start a separate thread to do so.
      def stop
        # Initialize the stopping process only if Karafka was running
        return if Karafka::App.stopping?
        return if Karafka::App.stopped?
        return if Karafka::App.terminated?

        Karafka::App.stop!

        timeout = shutdown_timeout

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        # We divide it by 1000 because we use time in ms.
        ((timeout / 1_000) * (1 / supervision_sleep)).to_i.times do
          all_listeners_stopped = listeners.all?(&:stopped?)
          all_workers_stopped = workers.none?(&:alive?)

          return if all_listeners_stopped && all_workers_stopped

          sleep(supervision_sleep)
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        Karafka.monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          type: 'app.stopping.error'
        )

        # We're done waiting, lets kill them!
        workers.each(&:terminate)
        listeners.active.each(&:terminate)

        # We always need to shutdown clients to make sure we do not force the GC to close consumer.
        # This can cause memory leaks and crashes.
        # We run it in a separate thread in case this would hang and we ignore it after the time
        # we assigned to it and force shutdown as we prefer to stop the process rather than wait
        # indefinitely even with risk of VM crash as this is a last resort.
        Thread.new do
          listeners.each(&:shutdown)
        rescue StandardError => e
          # If anything wrong happened during shutdown, we also want to record it
          Karafka.monitor.instrument(
            'error.occurred',
            caller: self,
            error: e,
            type: 'app.forceful_stopping.error'
          )
        end.join(FORCEFUL_SHUTDOWN_WAIT)

        # We also do not forcefully terminate everything when running in the embedded mode,
        # otherwise we would overwrite the shutdown process of the process that started Karafka
        return unless process.supervised?

        # exit! is not within the instrumentation as it would not trigger due to exit
        Kernel.exit!(forceful_exit_code)
      ensure
        # We need to check if it wasn't an early exit to make sure that only on stop invocation
        # can change the status after everything is closed
        if timeout
          Karafka::App.stopped!

          # We close producer as the last thing as it can be used in the notification pipeline
          # to dispatch state changes, etc
          Karafka::App.producer.close

          Karafka::App.terminate!
        end
      end

      # Quiets the Karafka server.
      #
      # Karafka will stop processing but won't quit the consumer group, so no rebalance will be
      # triggered until final shutdown.
      def quiet
        # We don't have to safe-guard it with check states as the state transitions work only
        # in one direction
        Karafka::App.quiet!
      end
    end

    # Always start with standalone so there always is a value for the execution mode.
    # This is overwritten quickly during boot, but just in case someone would reach it prior to
    # booting, we want to have the default value.
    self.execution_mode = :standalone

    self.id = SecureRandom.hex(6)
  end
end

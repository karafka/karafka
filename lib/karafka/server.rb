# frozen_string_literal: true

module Karafka
  # Karafka consuming server class
  class Server
    # How long should we sleep between checks on shutting down consumers
    SUPERVISION_SLEEP = 0.1
    # What system exit code should we use when we terminated forcefully
    FORCEFUL_EXIT_CODE = 2
    # This factor allows us to calculate how many times we have to sleep before
    # a forceful shutdown
    SUPERVISION_CHECK_FACTOR = (1 / SUPERVISION_SLEEP)

    private_constant :SUPERVISION_SLEEP, :FORCEFUL_EXIT_CODE, :SUPERVISION_CHECK_FACTOR

    class << self
      # Set of consuming threads. Each consumer thread contains a single consumer
      attr_accessor :consumer_threads

      # Set of workers
      attr_accessor :workers

      # Writer for list of consumer groups that we want to consume in our current process context
      attr_writer :consumer_groups

      # Method which runs app
      def run
        process.on_sigint { stop }
        process.on_sigquit { stop }
        process.on_sigterm { stop }

        # Start is blocking until stop is called and when we stop, it will wait until
        # all of the things are ready to stop
        start

        # We always need to wait for Karafka to stop here since we should wait for the stop running
        # in a separate thread (or trap context) to indicate everything is closed
        Thread.pass until Karafka::App.stopped?
      # Try its best to shutdown underlying components before re-raising
      # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        stop

        raise e
      end

      # @return [Array<String>] array with names of consumer groups that should be consumed in a
      #   current server context
      def consumer_groups
        # If not specified, a server will listen on all the topics
        @consumer_groups ||= Karafka::App.consumer_groups.map(&:name).freeze
      end

      # Starts Karafka with a supervision
      # @note We don't need to sleep because Karafka::Fetcher is locking and waiting to
      # finish loop (and it won't happen until we explicitly want to stop)
      def start
        process.supervise
        Karafka::App.run!
        Karafka::Runner.new.call
      end

      # Stops Karafka with a supervision (as long as there is a shutdown timeout)
      # If consumers or workers won't stop in a given time frame, it will force them to exit
      #
      # @note This method is not async. It should not be executed from the workers as it will
      #   lock them forever. If you need to run Karafka shutdown from within workers threads,
      #   please start a separate thread to do so.
      def stop
        Karafka::App.stop!

        timeout = Thread.new { Karafka::App.config.shutdown_timeout }.join.value

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        # We divide it by 1000 because we use time in ms.
        ((timeout / 1_000) * SUPERVISION_CHECK_FACTOR).to_i.times do
          if consumer_threads.count(&:alive?).zero? &&
             workers.count(&:alive?).zero?

            Thread.new { Karafka::App.producer.close }.join

            return
          end

          sleep SUPERVISION_SLEEP
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        thread = Thread.new do
          Karafka.monitor.instrument(
            'error.occurred',
            caller: self,
            error: e,
            type: 'app.stopping.error'
          )

          # We're done waiting, lets kill them!
          workers.each(&:terminate)
          consumer_threads.each(&:terminate)

          Karafka::App.producer.close
        end

        thread.join

        # exit! is not within the instrumentation as it would not trigger due to exit
        Kernel.exit! FORCEFUL_EXIT_CODE
      ensure
        Karafka::App.stopped!
      end

      private

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::App.config.internal.process
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Karafka consuming server class
  class Server
    @consumer_threads = Concurrent::Array.new

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

      # Writer for list of consumer groups that we want to consume in our current process context
      attr_writer :consumer_groups

      # Method which runs app
      def run
        process.on_sigint { stop_supervised }
        process.on_sigquit { stop_supervised }
        process.on_sigterm { stop_supervised }
        run_supervised
      end

      # @return [Array<String>] array with names of consumer groups that should be consumed in a
      #   current server context
      def consumer_groups
        # If not specified, a server will listed on all the topics
        @consumer_groups ||= Karafka::App.consumer_groups.map(&:name).freeze
      end

      private

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::App.config.internal.process
      end

      # Starts Karafka with a supervision
      # @note We don't need to sleep because Karafka::Fetcher is locking and waiting to
      # finish loop (and it won't happen until we explicitly want to stop)
      def run_supervised
        process.supervise
        Karafka::App.run!
        Karafka::App.config.internal.fetcher.call
      end

      # Stops Karafka with a supervision (as long as there is a shutdown timeout)
      # If consumers won't stop in a given time frame, it will force them to exit
      def stop_supervised
        Karafka::App.stop!

        # Temporary patch until https://github.com/dry-rb/dry-configurable/issues/93 is fixed
        timeout = Thread.new { Karafka::App.config.shutdown_timeout }.join.value

        # We check from time to time (for the timeout period) if all the threads finished
        # their work and if so, we can just return and normal shutdown process will take place
        (timeout * SUPERVISION_CHECK_FACTOR).to_i.times do
          if consumer_threads.count(&:alive?).zero?
            Thread.new { Karafka.monitor.instrument('app.stopped') }.join
            return
          end

          sleep SUPERVISION_SLEEP
        end

        raise Errors::ForcefulShutdownError
      rescue Errors::ForcefulShutdownError => e
        Thread.new { Karafka.monitor.instrument('app.stopping.error', error: e) }.join
        # We're done waiting, lets kill them!
        consumer_threads.each(&:terminate)

        # exit! is not within the instrumentation as it would not trigger due to exit
        Kernel.exit! FORCEFUL_EXIT_CODE
      end
    end
  end
end

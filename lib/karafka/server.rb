# frozen_string_literal: true

module Karafka
  # Karafka consuming server class
  class Server
    @consumer_threads = Concurrent::Array.new

    # How long should we sleep between checks on shutting down consumers
    SUPERVISION_SLEEP = 1
    # What system exit code should we use when we terminated forcefully
    FORCEFUL_EXIT_CODE = 2

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
        start_supervised
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
        Karafka::Process.instance
      end

      # Starts Karafka with a supervision
      # @note We don't need to sleep because Karafka::Fetcher is locking and waiting to
      # finish loop (and it won't happen until we explicitily want to stop)
      def start_supervised
        process.supervise
        Karafka::App.run!
        Karafka::Fetcher.call
      end

      # Stops Karafka with a supervision (as long as there is a shutdown timeout)
      # If consumers won't stop in a given timeframe, it will force them to exit
      def stop_supervised
        # Because this is called in the trap context, there is a chance that instrumentation
        # listeners contain things that aren't allowed from within a trap context.
        # To bypass that (instead of telling users not to do things they need to)
        # we spin up a thread to instrument server.stop and server.stop.error and wait until
        # they're finished
        Thread.new { Karafka.monitor.instrument('server.stop', {}) }.join

        Karafka::App.stop!
        # If there is no shutdown timeout, we don't exit and wait until all the consumers
        # had done their work
        return unless Karafka::App.config.shutdown_timeout

        # If there is a timeout, we check every 1 second (for the timeout period) if all
        # the threads finished their work and if so, we can just return and normal
        # shutdown process will take place
        Karafka::App.config.shutdown_timeout.to_i.times do
          return if consumer_threads.count(&:alive?).zero?
          sleep SUPERVISION_SLEEP
        end

        raise Errors::ForcefulShutdown
      rescue Errors::ForcefulShutdown => error
        Thread.new { Karafka.monitor.instrument('server.stop.error', error: error) }.join
        # We're done waiting, lets kill them!
        consumer_threads.each(&:terminate)

        # exit is not within the instrumentation as it would not trigger due to exit
        Kernel.exit FORCEFUL_EXIT_CODE
      end
    end
  end
end

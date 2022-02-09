# frozen_string_literal: true

module Karafka
  module Processing
    # Workers are used to run jobs in separate threads.
    # Workers are the main processing units of the Karafka framework.
    class Worker
      extend Forwardable

      def_delegators :@thread, :join, :terminate, :alive?

      # @param jobs_queue [JobsQueue]
      # @return [Worker]
      def initialize(jobs_queue)
        @jobs_queue = jobs_queue
        @thread = Thread.new do
          # If anything goes wrong in this worker thread, it means something went really wrong and
          # we should terminate.
          Thread.current.abort_on_exception = true
          loop { break unless process }
        end
      end

      private

      # Fetches a single job, processes it and marks as completed.
      #
      # @note We do not have error handling here, as no errors should propagate this far. If they
      #   do, it is a critical error and should bubble up.
      #
      # @note Upon closing the jobs queue, worker will close it's thread
      def process
        job = @jobs_queue.pop

        if job
          job.call
          true
        else
          false
        end
      # We signal critical exceptions, notify and do not allow worker to fail
      # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        Karafka.monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          type: 'worker.process.error'
        )
      ensure
        # job can be nil when the queue is being closed
        @jobs_queue.complete(job) if job
      end
    end
  end
end

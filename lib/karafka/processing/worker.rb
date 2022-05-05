# frozen_string_literal: true

module Karafka
  module Processing
    # Workers are used to run jobs in separate threads.
    # Workers are the main processing units of the Karafka framework.
    #
    # Each job runs in three stages:
    #   - prepare - here we can run any code that we would need to run blocking before we allow
    #               the job to run fully async (non blocking). This will always run in a blocking
    #               way and can be used to make sure all the resources and external dependencies
    #               are satisfied before going async.
    #
    #   - call - actual processing logic that can run sync or async
    #
    #   - teardown - it should include any code that we want to run after we executed the user
    #                code. This can be used to unlock certain resources or do other things that are
    #                not user code but need to run after user code base is executed.
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
          job.prepare

          # If a job is marked as non blocking, we can run a tick in the job queue and if there
          # are no other blocking factors, the job queue will be unlocked.
          # If this does not run, all the things will be blocking and job queue won't allow to
          # pass it until done.
          @jobs_queue.tick(job.group_id) if job.non_blocking?

          job.call

          job.teardown

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

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
      include Helpers::Async
      include Helpers::ConfigImporter.new(
        worker_job_call_wrapper: %i[internal processing worker_job_call_wrapper],
        monitor: %i[monitor]
      )

      # @return [String] id of this worker
      attr_reader :id

      # @param jobs_queue [JobsQueue]
      # @return [Worker]
      def initialize(jobs_queue)
        @id = SecureRandom.hex(6)
        @jobs_queue = jobs_queue
        @non_wrapped_flow = worker_job_call_wrapper == false
      end

      private

      # Runs processing of jobs in a loop
      # Stops when queue is closed.
      def call
        loop { break unless process }
      end

      # Fetches a single job, processes it and marks as completed.
      #
      # @note We do not have error handling here, as no errors should propagate this far. If they
      #   do, it is a critical error and should bubble up.
      #
      # @note Upon closing the jobs queue, worker will close it's thread
      def process
        job = @jobs_queue.pop

        instrument_details = { caller: self, job: job, jobs_queue: @jobs_queue }

        if job
          job.wrap do
            monitor.instrument('worker.process', instrument_details)

            monitor.instrument('worker.processed', instrument_details) do
              job.before_call

              # If a job is marked as non blocking, we can run a tick in the job queue and if there
              # are no other blocking factors, the job queue will be unlocked.
              # If this does not run, all the things will be blocking and job queue won't allow to
              # pass it until done.
              @jobs_queue.tick(job.group_id) if job.non_blocking?

              if @non_wrapped_flow
                job.call
              else
                worker_job_call_wrapper.wrap do
                  job.call
                end
              end

              job.after_call

              true
            end
          end
        else
          false
        end
      # We signal critical exceptions, notify and do not allow worker to fail
      # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        monitor.instrument(
          'error.occurred',
          caller: self,
          job: job,
          jobs_queue: @jobs_queue,
          error: e,
          type: 'worker.process.error'
        )
      ensure
        # job can be nil when the queue is being closed
        if job
          @jobs_queue.complete(job)
          job.finish!
        end

        # Always publish info, that we completed all the work despite its result
        monitor.instrument('worker.completed', instrument_details)
      end
    end
  end
end

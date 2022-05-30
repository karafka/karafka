# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka listeners in separate threads
  class Runner
    # Starts listening on all the listeners asynchronously and handles the jobs queue closing
    # after listeners are done with their work.
    def call
      # Despite possibility of having several independent listeners, we aim to have one queue for
      # jobs across and one workers poll for that
      jobs_queue = Processing::JobsQueue.new

      workers = Processing::WorkersBatch.new(jobs_queue)
      listeners = Connection::ListenersBatch.new(jobs_queue)

      workers.each(&:async_call)
      listeners.each(&:async_call)

      # We aggregate threads here for a supervised shutdown process
      Karafka::Server.workers = workers
      Karafka::Server.listeners = listeners

      # All the listener threads need to finish
      listeners.each(&:join)

      # We close the jobs queue only when no listener threads are working.
      # This ensures, that everything was closed prior to us not accepting anymore jobs and that
      # no more jobs will be enqueued. Since each listener waits for jobs to finish, once those
      # are done, we can close.
      jobs_queue.close

      # All the workers need to stop processing anything before we can stop the runner completely
      # This ensures that even async long-running jobs have time to finish before we are done
      # with everything. One thing worth keeping in mind though: It is the end user responsibility
      # to handle the shutdown detection in their long-running processes. Otherwise if timeout
      # is exceeded, there will be a forced shutdown.
      workers.each(&:join)
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something terrible happened
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        caller: self,
        error: e,
        type: 'runner.call.error'
      )
      Karafka::App.stop!
      raise e
    end
  end
end

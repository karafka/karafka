# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka listeners in separate threads
  class Runner
    include Helpers::ConfigImporter.new(
      manager: %i[internal connection manager],
      conductor: %i[internal connection conductor]
    )

    # Starts listening on all the listeners asynchronously and handles the jobs queue closing
    # after listeners are done with their work.
    def call
      jobs_queue = Karafka::Server.jobs_queue
      workers = Karafka::Server.workers

      # Wire up the circular dependency between pool and queue
      workers.jobs_queue = jobs_queue
      jobs_queue.pool = workers

      listeners = Connection::ListenersBatch.new(jobs_queue)

      # We mark it prior to delegating to the manager as manager will have to start at least one
      # connection to Kafka, hence running
      Karafka::App.run!

      # Register all the listeners so they can be started and managed
      manager.register(listeners)

      # We aggregate threads here for a supervised shutdown process
      Karafka::Server.listeners = listeners

      # Start worker threads after listeners are created so a failure in the boot steps above
      # does not leave live worker threads blocked on an open queue.
      workers.scale(Karafka::App.config.concurrency)

      until manager.done?
        conductor.wait

        manager.control
      end

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
      workers.join
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something terrible happened
    rescue => e
      Karafka.monitor.instrument(
        "error.occurred",
        caller: self,
        error: e,
        type: "runner.call.error"
      )
      Karafka::App.stop!

      # Clean up workers so we don't leak threads blocked on the queue
      jobs_queue.close
      workers.join

      raise e
    end
  end
end

# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka listeners in separate threads
  class Runner
    # Starts listening on all the listeners asynchronously and handles the jobs queue closing
    # after listeners are done with their work.
    def call
      # Despite possibility of having several independent listeners, we aim to have one queue for
      # jobs across and one workers poll for that
      jobs_queue = App.config.internal.processing.jobs_queue_class.new

      workers = Processing::WorkersBatch.new(jobs_queue)
      listeners = Connection::ListenersBatch.new(jobs_queue)

      workers.each(&:async_call)

      App.config.internal.connection.manager.register(listeners)

      # We aggregate threads here for a supervised shutdown process
      Karafka::Server.workers = workers
      Karafka::Server.listeners = listeners
      Karafka::Server.jobs_queue = jobs_queue

      wait_actively(listeners)

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

    private

    # Waits actively and publishes notification on each tick. This can be used to perform listener
    # related operations.
    #
    # @param listeners [Connection::ListenersBatch]
    def wait_actively(listeners)
      # Thread#join requires time in seconds, thus the conversion
      join_timeout = Karafka::App.config.internal.join_timeout / 1_000.0

      listeners.cycle do |listener|
        # Do not manage rebalances if we're done and shutting down
        break if Karafka::App.done?

        next unless listener.active?

        # If join returns something else than nil, it means this listener is either stopped or
        # paused and its timeout will not kick in. In such cases we do not use its timeout because
        # it is not time reliable and could trigger the event too often
        next unless listener.join(join_timeout).nil?

        Karafka.monitor.instrument('runner.join_timeout', caller: self)
      end

      # All the active listener threads need to finish when shutdown is happening
      # If we are here it means we're done and shutdown has started. During this period we no
      # longer tick from the runner but we still need to wait on all the listeners to finish all
      # the work
      listeners.active.each(&:join)
    end
  end
end

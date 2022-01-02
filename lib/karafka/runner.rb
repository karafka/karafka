# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka listeners in separate threads
  class Runner
    # Starts listening on all the listeners asynchronously
    # Fetch loop should never end. If they do, it is a critical error
    def call
      # Despite possibility of having several independent listeners, we aim to have one queue for
      # jobs across and one workers poll for that
      jobs_queue = Processing::JobsQueue.new

      workers = Processing::WorkersBatch.new(jobs_queue)
      Karafka::Server.workers = workers

      threads = listeners(jobs_queue).map do |listener|
        # We abort on exception because there should be an exception handling developed for
        # each listener running in separate threads, so the exceptions should never leak
        # and if that happens, it means that something really bad happened and we should stop
        # the whole process
        Thread
          .new { listener.call }
          .tap { |thread| thread.abort_on_exception = true }
      end

      # We aggregate threads here for a supervised shutdown process
      Karafka::Server.consumer_threads = threads

      # All the listener threads need to finish
      threads.each(&:join)
      # All the workers need to stop processing anything before we can stop the runner completely
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

    # @param jobs_queue [Processing::JobsQueue] the main processing queue
    # @return [Array<Karafka::Connection::Listener>] listeners that will consume messages for each
    #   of the subscription groups
    def listeners(jobs_queue)
      App
        .subscription_groups
        .map do |subscription_group|
          Karafka::Connection::Listener.new(subscription_group, jobs_queue)
        end
    end
  end
end

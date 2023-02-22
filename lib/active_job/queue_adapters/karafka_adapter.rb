# frozen_string_literal: true

# ActiveJob components to allow for jobs consumption with Karafka
module ActiveJob
  # ActiveJob queue adapters
  module QueueAdapters
    # Karafka adapter for enqueuing jobs
    # This is here for ease of integration with ActiveJob.
    class KarafkaAdapter
      # Enqueues the job using the configured dispatcher
      #
      # @param job [Object] job that should be enqueued
      def enqueue(job)
        ::Karafka::App.config.internal.active_job.dispatcher.dispatch(job)
      end

      # Enqueues multiple jobs in one go
      # @param jobs [Array<Object>] jobs that we want to enqueue
      def enqueue_all(jobs)
        ::Karafka::App.config.internal.active_job.dispatcher.dispatch_many(jobs)
      end

      # Raises info, that Karafka backend does not support scheduling jobs
      #
      # @param _job [Object] job we cannot enqueue
      # @param _timestamp [Time] time when job should run
      def enqueue_at(_job, _timestamp)
        raise NotImplementedError, 'This queueing backend does not support scheduling jobs.'
      end
    end
  end
end

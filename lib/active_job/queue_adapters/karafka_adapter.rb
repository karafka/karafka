# frozen_string_literal: true

# ActiveJob components to allow for jobs consumption with Karafka
module ActiveJob
  # ActiveJob queue adapters
  module QueueAdapters
    # Karafka adapter for enqueuing jobs
    # This is here for ease of integration with ActiveJob.
    class KarafkaAdapter
      include Karafka::Helpers::ConfigImporter.new(
        dispatcher: %i[internal active_job dispatcher]
      )

      # Enqueues the job using the configured dispatcher
      #
      # @param job [Object] job that should be enqueued
      def enqueue(job)
        dispatcher.dispatch(job)
      end

      # Enqueues multiple jobs in one go
      # @param jobs [Array<Object>] jobs that we want to enqueue
      # @return [Integer] number of jobs enqueued (required by Rails)
      def enqueue_all(jobs)
        dispatcher.dispatch_many(jobs)
        jobs.size
      end

      # Delegates time sensitive dispatch to the dispatcher. OSS will raise error, Pro will handle
      # this as it supports scheduled messages.
      #
      # @param job [Object] job we want to enqueue
      # @param timestamp [Time] time when job should run
      def enqueue_at(job, timestamp)
        dispatcher.dispatch_at(job, timestamp)
      end

      # @return [true] should we by default enqueue after the transaction and not during.
      #   Defaults to true to prevent weird issues during rollbacks, etc.
      def enqueue_after_transaction_commit?
        true
      end
    end
  end
end

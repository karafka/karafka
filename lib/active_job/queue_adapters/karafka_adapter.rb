# frozen_string_literal: true

# ActiveJob components to allow for jobs consumption with Karafka
module ActiveJob
  # ActiveJob queue adapters
  module QueueAdapters
    # Determine the appropriate base class for the Karafka adapter.
    #
    # This complex inheritance logic addresses a Rails 7.1 compatibility issue where
    # ActiveJob::QueueAdapters::AbstractAdapter is not properly autoloaded during
    # early initialization phases, causing "uninitialized constant" errors.
    #
    # The issue occurs because:
    # 1. AbstractAdapter is autoloaded, not directly required in Rails 7+
    # 2. Rails 7.1 has specific timing issues during the boot process
    # 3. Queue adapters may be loaded before Rails completes initialization
    #
    # Inheritance strategy:
    # - Rails 7.1: Inherit from Object (avoids AbstractAdapter autoloading issues)
    # - Other Rails versions: Inherit from AbstractAdapter (normal behavior)
    # - No Rails: Inherit from Object (standalone ActiveJob usage)
    #
    # @see https://github.com/sidekiq/sidekiq/issues/6746 Similar issue in Sidekiq
    base = if defined?(Rails) && defined?(Rails::VERSION)
             (Rails::VERSION::MAJOR == 7 && Rails::VERSION::MINOR < 2 ? Object : AbstractAdapter)
           else
             # Fallback when Rails is not loaded
             Object
           end

    # Karafka adapter for enqueuing jobs
    # This is here for ease of integration with ActiveJob.
    class KarafkaAdapter < base
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

      # @return [Boolean] should we stop the job. Used by the ActiveJob continuation feature
      def stopping?
        ::Karafka::App.done?
      end
    end
  end
end

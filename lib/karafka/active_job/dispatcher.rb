# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Dispatcher that sends the ActiveJob job to a proper topic based on the queue name
    class Dispatcher
      include Helpers::ConfigImporter.new(
        deserializer: %i[internal active_job deserializer]
      )

      # Defaults for dispatching
      # The can be updated by using `#karafka_options` on the job
      DEFAULTS = {
        dispatch_method: :produce_async,
        dispatch_many_method: :produce_many_async
      }.freeze

      private_constant :DEFAULTS

      # @param job [ActiveJob::Base] job
      def dispatch(job)
        ::Karafka.producer.public_send(
          fetch_option(job, :dispatch_method, DEFAULTS),
          topic: job.queue_name,
          payload: serialize_job(job)
        )
      end

      # Bulk dispatches multiple jobs using the Rails 7.1+ API
      # @param jobs [Array<ActiveJob::Base>] jobs we want to dispatch
      def dispatch_many(jobs)
        # Group jobs by their desired dispatch method
        # It can be configured per job class, so we need to make sure we divide them
        dispatches = Hash.new { |hash, key| hash[key] = [] }

        jobs.each do |job|
          d_method = fetch_option(job, :dispatch_many_method, DEFAULTS)

          dispatches[d_method] << {
            topic: job.queue_name,
            payload: serialize_job(job)
          }
        end

        dispatches.each do |type, messages|
          ::Karafka.producer.public_send(
            type,
            messages
          )
        end
      end

      # Raises info, that Karafka backend does not support scheduling jobs if someone wants to
      # schedule jobs in the future. It works for past and present because we want to support
      # things like continuation and `#retry_on` API with no wait and no jitter.
      #
      # @param job [Object] job we cannot enqueue
      # @param timestamp [Time] time when job should run
      #
      # @note Karafka Pro supports future jobs via the Scheduled Messages feature
      #
      # @note For ActiveJob Continuation to work without Pro, configure your continuable jobs:
      #   self.resume_options = { wait: 0 }
      #
      # @note For `#retry_on` to work without Pro, configure with:
      #   retry_on SomeError, wait: 0, jitter: 0
      def dispatch_at(job, timestamp)
        # Dispatch at is used by some of the ActiveJob features that actually do not back-off
        # but things go via this API nonetheless.
        if timestamp.to_f <= Time.now.to_f
          dispatch(job)
        else
          raise NotImplementedError, <<~ERROR_MESSAGE
            This queueing backend does not support scheduling future jobs.

            If you're using ActiveJob Continuation, configure your jobs with:
              self.resume_options = { wait: 0 }

            If you're using retry_on, configure with:
              retry_on SomeError, wait: 0, jitter: 0

            For full support of delayed job execution, consider using Karafka Pro with Scheduled Messages.
          ERROR_MESSAGE
        end
      end

      private

      # Serializes a job using the configured deserializer
      # This method serves as an extension point and can be wrapped by modules like
      # CurrentAttributes::Persistence
      #
      # @param job [ActiveJob::Base, CurrentAttributes::Persistence::JobWrapper] job to serialize.
      #   When CurrentAttributes are used, this may be a JobWrapper instead of the original job.
      # @return [String] serialized job payload
      def serialize_job(job)
        deserializer.serialize(job)
      end

      # @param job [ActiveJob::Base] job
      # @param key [Symbol] key we want to fetch
      # @param defaults [Hash]
      # @return [Object] options we are interested in
      def fetch_option(job, key, defaults)
        job
          .class
          .karafka_options
          .fetch(key, defaults.fetch(key))
      end
    end
  end
end

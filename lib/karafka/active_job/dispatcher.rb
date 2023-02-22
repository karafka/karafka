# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Dispatcher that sends the ActiveJob job to a proper topic based on the queue name
    class Dispatcher
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
          payload: ::ActiveSupport::JSON.encode(job.serialize)
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
            payload: ::ActiveSupport::JSON.encode(job.serialize)
          }
        end

        dispatches.each do |type, messages|
          ::Karafka.producer.public_send(
            type,
            messages
          )
        end
      end

      private

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

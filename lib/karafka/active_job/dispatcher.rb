# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Dispatcher that sends the ActiveJob job to a proper topic based on the queue name
    class Dispatcher
      # Defaults for dispatching
      # The can be updated by using `#karafka_options` on the job
      DEFAULTS = {
        dispatch_method: :produce_async
      }.freeze

      private_constant :DEFAULTS

      # @param job [ActiveJob::Base] job
      def call(job)
        ::Karafka.producer.public_send(
          fetch_option(job, :dispatch_method, DEFAULTS),
          topic: job.queue_name,
          payload: ::ActiveSupport::JSON.encode(job.serialize)
        )
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

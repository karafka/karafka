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
        # We can either dispatch sync (slower) or async (faster)
        dispatch_method = job
                          .class
                          .karafka_options
                          .fetch(:dispatch_method, DEFAULTS[:dispatch_method])

        ::Karafka.producer.public_send(
          dispatch_method,
          topic: job.queue_name,
          payload: ::ActiveSupport::JSON.encode(job.serialize)
        )
      end
    end
  end
end

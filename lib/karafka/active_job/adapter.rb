# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Karafka ActiveJob adapter for using Kafka as an ActiveJob backend
    module Adapter
      # Enqueues the job by sending all the payload to a dedicated topic in Kafka that will be
      # later on consumed by a special ActiveJob consumer
      #
      # @param job [Object] job that should be enqueued
      def enqueue(job)
        ::Karafka.producer.public_send(
          job.class.karafka_options.fetch(:dispatch_method),
          topic: job.queue_name,
          payload: ::ActiveSupport::JSON.encode(job.serialize)
        )
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

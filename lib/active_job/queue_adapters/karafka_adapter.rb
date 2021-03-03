# frozen_string_literal: true

# ActiveJob components to allow for jobs consumption with Karafka
module ActiveJob
  # ActiveJob queue adapters
  module QueueAdapters
    # Karafka adapter for enqueuing jobs
    class KarafkaAdapter
      # Enqueues the job by sending all the payload to a dedicated topic in Kafka that will be
      # later on consumed by a special ActiveJob consumer
      #
      # @param job [Object] job that should be enqueued
      def enqueue(job)
        ::Karafka.producer.produce_async(
          topic: job.queue_name,
          payload: ActiveSupport::JSON.encode(job.serialize)
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

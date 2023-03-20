# frozen_string_literal: true

module Karafka
  # Namespace for all the ActiveJob related things from within Karafka
  module ActiveJob
    # This is the consumer for ActiveJob that eats the messages enqueued with it one after another.
    # It marks the offset after each message, so we make sure, none of the jobs is executed twice
    class Consumer < ::Karafka::BaseConsumer
      # Executes the ActiveJob logic
      # @note ActiveJob does not support batches, so we just run one message after another
      def consume
        messages.each do |message|
          break if Karafka::App.stopping?

          # We technically speaking could set this as deserializer and reference it from the
          # message instead of using the `#raw_payload`. This is not done on purpose to simplify
          # the ActiveJob setup here
          job = ::ActiveSupport::JSON.decode(message.raw_payload)

          tags.add(:job_class, job['job_class'])

          payload = { caller: self, job: job, message: message }

          # We publish both to make it consistent with `consumer.x` events
          Karafka.monitor.instrument('active_job.consume', payload)
          Karafka.monitor.instrument('active_job.consumed', payload) do
            ::ActiveJob::Base.execute(job)
          end

          mark_as_consumed(message)
        end
      end
    end
  end
end

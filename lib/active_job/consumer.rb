# frozen_string_literal: true

module ActiveJob
  # This is the consumer for ActiveJob that eats the messages enqueued with it one after another.
  # It marks the offset after each message, so we make sure, none of the jobs is executed twice
  class Consumer < Karafka::BaseConsumer
    # Executes the ActiveJob logic
    # @note ActiveJob does not support batches, so we just run one message after another
    def consume
      messages.each do |message|
        ActiveJob::Base.execute(
          ActiveSupport::JSON.decode(message.raw_payload)
        )

        mark_as_consumed(message)
      end
    end
  end
end

# frozen_string_literal: true

module Karafka
  module ActiveJob
    # This is the consumer for ActiveJob that eats the messages enqueued with it one after another.
    # It marks the offset after each message, so we make sure, none of the jobs is executed twice
    class Consumer < ::Karafka::BaseConsumer
      # Executes the ActiveJob logic
      # @note ActiveJob does not support batches, so we just run one message after another
      def consume
        messages.each do |message|
          break if Karafka::App.stopping?

          ::ActiveJob::Base.execute(
            # We technically speaking could set this as deserializer and reference it from the
            # message instead of using the `#raw_payload`. This is not done on purpose to simplify
            # the ActiveJob setup here
            ::ActiveSupport::JSON.decode(message.raw_payload)
          )

          mark_as_consumed(message)
        end
      end
    end
  end
end

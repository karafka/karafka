# frozen_string_literal: true

module Karafka
  module ActiveJob
    # This is the consumer for ActiveJob that eats the messages enqueued with it one after another.
    # It marks the offset after each message, so we make sure, none of the jobs is executed twice
    class Consumer < ::Karafka::BaseConsumer
      # Defaults for consuming
      # The can be updated by using `#karafka_options` on the job
      DEFAULTS = {
        timeout: 300000,          # (5 minutes)
        max_poll_interval: 300000 # (5 minutes) default max.poll.interval.ms
      }.freeze

      # Executes the ActiveJob logic
      # @note ActiveJob does not support batches, so we just run one message after another
      def consume
        messages.each do |message|
          # Decode as JSON so we can get the Job Class (Required for finding karafka_options)
          decoded_message_payload = ::ActiveSupport::JSON.decode(message.raw_payload)

          begin
            # Pause the consumer for this message partition - so we can poll without receiving
            # new records
            client.pause_without_reversal(topic.name, message.partition)

            # Any thread exceptions will be re-raised in the main thread.
            Thread.abort_on_exception = true

            keep_alive_interval = Karafka::App.config.kafka[:'max.poll.interval.ms'] ||= DEFAULTS.fetch('max_poll_interval')
            keep_alive_interval = keep_alive_interval / 2

            # Continue calling poll while the job_thread is still working
            #  - Prevents Kafka marking the consumer as 'dead'
            heartbeat_thread = Thread.new do
              while true
                # This timeout will always be hit as no records can be pulled while the partition
                # is paused.
                client.keep_alive_poll(timeout: keep_alive_interval)
              end
            end

            job_thread = Thread.new do
              ::ActiveJob::Base.execute(decoded_message_payload)
            end

            # After timeout kill heartbeat thread
            timeout_thread = Thread.new do
              # Fetch the timeout for the Job class
              # Divide by 1000 for milliseconds float precision
              timeout = fetch_option(decoded_message_payload['job_class'], :timeout, DEFAULTS) / 1000.0
              sleep(timeout)

              # TODO: This functionality could potentially be definable
              #  - What do you want your Job to do on Timeout:
              #    - Continue running until close
              #    - Raise as bellow and stop
              job_thread.raise(RuntimeError)
            end

            # Wait until the Job thread has completed
            job_thread.join

            mark_as_consumed(message)

            # TODO: On error we could give them option to mark the message as consumed and possibly publish it to a
            #   dead letter topic - its unlikely that the message will retry with a successful result
          ensure
            # Ensure we close all the threads in case of an unforeseen error
            Thread.kill(job_thread)
            Thread.kill(timeout_thread)
            Thread.kill(heartbeat_thread)
            # Wait until all threads are dead
            job_thread.join
            timeout_thread.join
            heartbeat_thread.join
            # Resume the consumer for the message partition - so we can continue to pull messages
            client.resume(topic.name, message.partition)
          end
        end
      end

      # @param job [String] job class name
      # @param key [Symbol] key we want to fetch
      # @param defaults [Hash]
      # @return [Object] options we are interested in
      def fetch_option(job, key, defaults)
        job
          .constantize
          .karafka_options
          .fetch(key, defaults.fetch(key))
      end
    end
  end
end

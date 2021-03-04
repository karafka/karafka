# frozen_string_literal: true

module Karafka
  module Processing
    # Executors:
    # - run consumers code with provided messages batch (for `#call`) or run given teardown
    #   operations when needed from separate threads
    # - they re-create consumer instances in case of partitions that were revoked and assigned back
    class Executor
      # @return [String] unique id that we use to ensure, that jobs running in paralle do not run
      #   for the same executor same time in different threads
      attr_reader :id

      attr_reader :group_id

      # @param client [Karafka::Connection::Client] kafka client
      # @param topic [Karafka::Routing::Topic] topic for which this executor will run
      # @param pause [Karafka::TimeTrackers::Pause] fetch pause object for crash pausing
      # @param jobs_queue [Karafka::Processing::JobsQueue] jobs queue (needed as we need to clear
      #   it in case of a processing error)
      def initialize(group_id, client, topic, pause)
        @id = SecureRandom.uuid
        @group_id = group_id
        @client = client
        @topic = topic
        @pause = pause
      end

      # Runs consumer data processing against given batch and handles failures and errors
      #
      # @param messages [Array<Rdkafka::Consumer::Message>] raw rdkafka messages
      # @param received_at [Time] the moment we've received the batch (actually the moment we've)
      #   enqueued it, but good enough
      def consume(messages, received_at)
        # First we build messages batch...
        consumer.messages = Messages::Builders::Messages.call(
          messages,
          @topic,
          received_at
        )

        # We run the consumer client logic...
        consumer.on_consume
      rescue StandardError => e
        # TODO insturmentacja here

        p e
      end

      # Runs the controller `#revoked` method that should be triggered when a given consumer is
      # no longer needed due to partitions reassignment.
      #
      # @note Clearing the consumer will ensure, that if we get the partition back, it will be
      #   handled with a consumer with a clean state.
      def revoked
        consumer.on_revoked
        @consumer = nil
      rescue StandardError => e
        # TODO insturmentacja here
        p e
      end

      # Runs the controller `#shutdown` method that should be triggered when a given consumer is
      # no longer needed as we're closing the process.
      # @note While we do not need to clear the consumer here, it's a good habit to clean after
      #   work is done.
      def shutdown
        consumer.on_shutdown
        @consumer = nil
      rescue StandardError => e
        # TODO insturmentacja here
        p e
      end

      private

      # @return [Object] cached consumer instance
      def consumer
        @consumer ||= begin
          consumer = @topic.consumer.new
          consumer.topic = @topic
          consumer.client = @client
          consumer.pause = @pause
          consumer
        end
      end
    end
  end
end

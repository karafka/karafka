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

      # @param client [Karafka::Connection::Client] kafka client
      # @param topic [Karafka::Routing::Topic] topic for which this executor will run
      # @param pause [Karafka::TimeTrackers::Pause] fetch pause object for crash pausing
      # @param jobs_queue [Karafka::Processing::JobsQueue] jobs queue (needed as we need to clear
      #   it in case of a processing error)
      def initialize(client, topic, pause)
        @id = SecureRandom.uuid
        @client = client
        @topic = topic
        @pause = pause
      end

      # Runs consumer data processing against given batch and handles failures and errors
      # @param messages[]
      # @param received_at []
      def call(messages, received_at)
        # First we build messages batch...
        consumer.messages = Messages::Builders::Messages.call(
          messages,
          @topic,
          received_at
        )

        # We run the consumer client logic...
        consumer.call
      end

      def revoked
        consumer.revoked
        @consumer = nil
      rescue StandardError => e
        # TODO insturmentacja here
        p e
      end

      def shutdown
        consumer.shutdown
        @consumer = nil
      rescue StandardError => e
        # TODO insturmentacja here
        p e
      end

      private

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

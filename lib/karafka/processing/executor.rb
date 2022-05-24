# frozen_string_literal: true

module Karafka
  # Namespace that encapsulates all the logic related to processing data.
  module Processing
    # Executors:
    # - run consumers code (for `#call`) or run given preparation / teardown operations when needed
    #   from separate threads.
    # - they re-create consumer instances in case of partitions that were revoked and assigned
    #   back.
    #
    # @note Executors are not removed after partition is revoked. They are not that big and will
    #   be re-used in case of a re-claim
    class Executor
      # @return [String] unique id that we use to ensure, that we use for state tracking
      attr_reader :id

      # @return [String] subscription group id to which a given executor belongs
      attr_reader :group_id

      attr_reader :messages

      # @param group_id [String] id of the subscription group to which the executor belongs
      # @param client [Karafka::Connection::Client] kafka client
      # @param topic [Karafka::Routing::Topic] topic for which this executor will run
      # @param pause_tracker [Karafka::TimeTrackers::Pause] fetch pause tracker for pausing
      def initialize(group_id, client, topic, pause_tracker)
        @id = SecureRandom.uuid
        @group_id = group_id
        @client = client
        @topic = topic
        @pause_tracker = pause_tracker
      end

      # Builds the consumer instance and sets all that is needed to run the user consumption logic
      #
      # @param messages [Array<Rdkafka::Consumer::Message>] raw rdkafka messages
      # @param received_at [Time] the moment we've received the batch (actually the moment we've)
      #   enqueued it, but good enough
      def prepare(messages, received_at)
        # Recreate consumer with each batch if persistence is not enabled
        # We reload the consumers with each batch instead of relying on some external signals
        # when needed for consistency. That way devs may have it on or off and not in this
        # middle state, where re-creation of a consumer instance would occur only sometimes
        @consumer = nil unless ::Karafka::App.config.consumer_persistence

        # First we build messages batch...
        consumer.messages = Messages::Builders::Messages.call(
          messages,
          @topic,
          received_at
        )

        consumer.on_prepared
      end

      # Runs consumer data processing against given batch and handles failures and errors.
      def consume
        # We run the consumer client logic...
        consumer.on_consume
      end

      # Runs the controller `#revoked` method that should be triggered when a given consumer is
      # no longer needed due to partitions reassignment.
      #
      # @note Clearing the consumer will ensure, that if we get the partition back, it will be
      #   handled with a consumer with a clean state.
      #
      # @note We run it only when consumer was present, because presence indicates, that at least
      #   a single message has been consumed.
      def revoked
        consumer.on_revoked if @consumer
        @consumer = nil
      end

      # Runs the controller `#shutdown` method that should be triggered when a given consumer is
      # no longer needed as we're closing the process.
      #
      # @note While we do not need to clear the consumer here, it's a good habit to clean after
      #   work is done.
      def shutdown
        # There is a case, where the consumer no longer exists because it was revoked, in case like
        # that we do not build a new instance and shutdown should not be triggered.
        consumer.on_shutdown if @consumer
        @consumer = nil
      end

      private

      # @return [Object] cached consumer instance
      def consumer
        @consumer ||= begin
          consumer = @topic.consumer.new
          consumer.topic = @topic
          consumer.client = @client
          consumer.pause_tracker = @pause_tracker
          consumer.producer = ::Karafka::App.producer
          consumer
        end
      end
    end
  end
end

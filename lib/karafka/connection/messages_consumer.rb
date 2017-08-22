# frozen_string_literal: true

module Karafka
  module Connection
    # Class used as a wrapper around Ruby-Kafka to simplify additional
    # features that we provide/might provide in future
    class MessagesConsumer
      # Creates a queue consumer that will pull the data from Kafka
      # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group for which
      #   we create a client
      # @return [Karafka::Connection::MessagesConsumer] group consumer that can subscribe to
      #   multiple topics
      def initialize(consumer_group)
        @consumer_group = consumer_group
      end

      # Opens connection, gets messages and calls a block for each of the incoming messages
      # @yieldparam [Array<Kafka::FetchedMessage>] kafka fetched messages
      # @note This will yield with raw messages - no preprocessing or reformatting.
      def fetch_loop
        send(
          consumer_group.batch_consuming ? :consume_each_batch : :consume_each_message
        ) { |messages| yield(messages) }
      rescue Kafka::ProcessingError => e
        # If there was an error during processing, we have to log it, pause current partition
        # and process other things
        Karafka.monitor.notice_error(self.class, e.cause)
        pause(e.topic, e.partition)
        retry
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self.class, e)
        retry
      end

      # Gracefuly stops topic consumption
      def stop
        @kafka_consumer&.stop
        @kafka_consumer = nil
      end

      private

      attr_reader :consumer_group

      # Pauses processing of a given topic partition
      # @param topic [String] topic that we want to pause
      # @param partition [Integer] number partition that we want to pause
      def pause(topic, partition)
        settings = ConfigAdapter.pausing(consumer_group)
        return false unless settings[:timeout].positive?
        kafka_consumer.pause(topic, partition, settings)
        true
      end

      # Consumes messages from Kafka in batches
      # @yieldparam [Array<Kafka::FetchedMessage>] kafka fetched messages
      def consume_each_batch
        kafka_consumer.each_batch(
          ConfigAdapter.consuming(consumer_group)
        ) do |batch|
          yield(batch.messages)
        end
      end

      # Consumes messages from Kafka one by one
      # @yieldparam [Array<Kafka::FetchedMessage>] kafka fetched messages
      def consume_each_message
        kafka_consumer.each_message(
          ConfigAdapter.consuming(consumer_group)
        ) do |message|
          #   always yield an array of messages, so we have consistent API (always a batch)
          yield([message])
        end
      end

      # @return [Kafka::Consumer] returns a ready to consume Kafka consumer
      #   that is set up to consume from topics of a given consumer group
      def kafka_consumer
        @kafka_consumer ||= kafka.consumer(
          ConfigAdapter.consumer(consumer_group)
        ).tap do |consumer|
          consumer_group.topics.each do |topic|
            consumer.subscribe(*ConfigAdapter.subscription(topic))
          end
        end
      rescue Kafka::ConnectionError
        # If we would not wait it would totally spam log file with failed
        # attempts if Kafka is down
        sleep(consumer_group.reconnect_timeout)
        # We don't log and just reraise - this will be logged
        # down the road
        raise
      end

      # @return [Kafka] returns a Kafka
      # @note We don't cache it internally because we cache kafka_consumer that uses kafka
      #   object instance
      def kafka
        Kafka.new(ConfigAdapter.client(consumer_group))
      end
    end
  end
end

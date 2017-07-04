# frozen_string_literal: true

module Karafka
  module Connection
    # Class used as a wrapper around Ruby-Kafka to simplify additional
    # features that we provide/might provide in future
    class TopicConsumer
      # How long should we wait before trying to reconnect to Kafka cluster
      # that went down (in seconds)
      RECONNECT_TIMEOUT = 5

      # Creates a queue consumer that will pull the data from Kafka
      # @param [Karafka::Routing::Route] route details that will be used to build up a
      #   queue consumer instance
      # @return [Karafka::Connection::QueueConsumer] queue consumer instance
      def initialize(route)
        @route = route
      end

      # Opens connection, gets messages and calls a block for each of the incoming messages
      # @yieldparam [Kafka::FetchedMessage] kafka fetched message
      # @note This will yield with a raw message - no preprocessing or reformatting
      def fetch_loop
        send(
          @route.batch_mode ? :consume_each_batch : :consume_each_message
        ) do |message|
          yield(message)
        end
      end

      # Gracefuly stops topic consumption
      def stop
        @kafka_consumer&.stop
        @kafka_consumer = nil
      end

      private

      # Consumes messages from Kafka in batches
      # @yieldparam [Kafka::FetchedMessage] kafka fetched message
      def consume_each_batch
        kafka_consumer.each_batch do |batch|
          batch.messages.each do |message|
            yield(message)
          end
        end
      end

      # Consumes messages from Kafka one by one
      # @yieldparam [Kafka::FetchedMessage] kafka fetched message
      def consume_each_message
        kafka_consumer.each_message do |message|
          yield(message)
        end
      end

      # @return [Kafka::Consumer] returns a ready to consume Kafka consumer
      #   that is set up to consume a given routes topic
      def kafka_consumer
        @kafka_consumer ||= kafka.consumer(
          ConfigAdapter.consumer(@route)
        ).tap do |consumer|
          consumer.subscribe(
            *ConfigAdapter.subscription(@route)
          )
        end
      rescue Kafka::ConnectionError
        # If we would not wait it would totally spam log file with failed
        # attempts if Kafka is down
        sleep(RECONNECT_TIMEOUT)
        # We don't log and just reraise - this will be logged
        # down the road
        raise
      end

      # @return [Kafka] returns a Kafka
      # @note We don't cache it internally because we cache kafka_consumer that uses kafka
      #   object instance
      def kafka
        Kafka.new(ConfigAdapter.client(@route))
      end
    end
  end
end

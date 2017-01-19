module Karafka
  module Connection
    # Class used as a wrapper around Ruby-Kafka to simplify additional
    # features that we provide/might provide in future
    class TopicConsumer
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
          group_id: @route.group,
          session_timeout: ::Karafka::App.config.kafka.session_timeout,
          offset_commit_interval: ::Karafka::App.config.kafka.offset_commit_interval,
          offset_commit_threshold: ::Karafka::App.config.kafka.offset_commit_threshold,
          heartbeat_interval: ::Karafka::App.config.kafka.heartbeat_interval
        ).tap { |consumer| consumer.subscribe(@route.topic) }
      end

      # @return [Kafka] returns a Kafka
      # @note We don't cache it internally because we cache kafka_consumer that uses kafka
      #   object instance
      def kafka
        Kafka.new(
          seed_brokers: ::Karafka::App.config.kafka.hosts,
          logger: ::Karafka.logger,
          client_id: ::Karafka::App.config.name,
          ssl_ca_cert: ::Karafka::App.config.kafka.ssl.ca_cert,
          ssl_client_cert: ::Karafka::App.config.kafka.ssl.client_cert,
          ssl_client_cert_key: ::Karafka::App.config.kafka.ssl.client_cert_key
        )
      end
    end
  end
end

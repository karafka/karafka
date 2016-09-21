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

      def fetch_loop
        kafka_consumer.each_message do |message|
          yield(message)
        end
      end

      def stop
        kafka_consumer.stop
        @kafka_consumer = nil
      end

      private

      def kafka_consumer
        return @kafka_consumer if @kafka_consumer

        kafka = Kafka.new(
          seed_brokers: ::Karafka::App.config.kafka.hosts,
          logger: ::Karafka.logger
        )

        @kafka_consumer = kafka.consumer(group_id: @route.group)
        @kafka_consumer.subscribe(@route.topic)
        @kafka_consumer
      end
    end
  end
end

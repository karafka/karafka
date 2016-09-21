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
        target.each_message do |message|
          yield(message)
        end
      end

      def stop
        target.stop
        @target = nil
      end

      private

      # @return [Poseidon::ConsumerGroup] consumer group instance
      def target
        return @target if @target

        kafka = Kafka.new(
          seed_brokers: ::Karafka::App.config.kafka.hosts,
          logger: ::Karafka.logger
        )

        @target = kafka.consumer(group_id: @route.group)
        @target.subscribe(@route.topic)
        @target
      end
    end
  end
end

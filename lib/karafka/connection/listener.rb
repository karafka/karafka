module Karafka
  module Connection
    # A single listener that listens to incoming events from a single topic
    class Listener
      # Errors that we catch and ignore
      # We should not take any action if one of this happens
      # Instead we just log it and proceed
      IGNORED_ERRORS = [
        Poseidon::Connection::ConnectionFailedError,
        ZK::Exceptions::OperationTimeOut
      ]

      # @param controller [Karafka::BaseController] a descendant of base controller
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(controller)
        @controller = controller
      end

      # Opens connection, gets events bulk and yields a block for each of the incoming messages
      # After everything is done, consumer connection is being closed so it cannot be used again
      # @note You cannot use again a closed connection
      def fetch
        consumer.fetch do |_partition, events_bulk|
          events_bulk.each do |incoming_message|
            yield(event(incoming_message))
          end
        end
      rescue *IGNORED_ERRORS
        consumer
      ensure
        consumer.close
      end

      private

      # Builds an event that contains a topic and a message value
      # @param incoming_message [Poseidon::FetchedMessage] a single poseidon message
      # @return [Karafka::Connection::Event] a single internal event
      def event(incoming_message)
        Event.new(@controller.topic, incoming_message.value)
      end

      # @return [Poseidon::ConsumerGroup] consumer group that listens to a topic
      def consumer
        @consumer ||= Poseidon::ConsumerGroup.new(
          @controller.group.to_s,
          Karafka::App.config.kafka_hosts,
          Karafka::App.config.zookeeper_hosts,
          @controller.topic.to_s
        )
      end
    end
  end
end

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single topic
    class Listener
      # Errors that we catch and ignore
      # We should not take any action if one of this happens
      # Instead we just log it and proceed
      IGNORED_ERRORS = [
        Poseidon::Connection::ConnectionFailedError,
        ZK::Exceptions::OperationTimeOut
      ]

      attr_reader :controller

      # @param controller [Karafka::BaseController] a descendant of base controller
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(controller)
        @controller = controller
      end

      # Opens connection, gets messages bulk and yields a block for each of the incoming messages
      # After everything is done, consumer connection is being closed so it cannot be used again
      # @note You cannot use again a closed connection
      def fetch
        consumer.fetch do |_partition, messages_bulk|
          messages_bulk.each do |incoming_message|
            yield(message(incoming_message))
          end
        end
      rescue *IGNORED_ERRORS => e
        Karafka.logger.error("An ignored error occur in #{self.class}")
        Karafka.logger.error(e)
      ensure
        consumer.close
      end

      private

      # Builds an message that contains a topic and a message value
      # @param incoming_message [Poseidon::FetchedMessage] a single poseidon message
      # @return [Karafka::Connection::Message] a single internal message
      def message(incoming_message)
        Message.new(@controller.topic, incoming_message.value)
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

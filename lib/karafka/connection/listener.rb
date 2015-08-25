module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single topic
    class Listener
      include Celluloid

      # Errors that we catch and ignore
      # We should not take any action if one of this happens
      # Instead we just log it and proceed
      IGNORED_ERRORS = [
        ZK::Exceptions::OperationTimeOut,
        Poseidon::Connection::ConnectionFailedError
      ]

      attr_reader :controller

      # @param controller [Karafka::BaseController] a descendant of base controller
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(controller)
        @stop = false
        @stopped = false
        @controller = controller
      end

      # Should we stop fetching messages
      # @note We will stop after the internal the fetch method is done fetching
      #   because we don't want to loose messages that Kafka already send to us
      # @example Loop until stop
      #   loop { break if stop? }
      def stop?
        @stop == true
      end

      # Stop fetching messages
      # @note It will stop fetching but it will finish processing anything that is
      #   already fetched, so it might now work immediately
      def stop!
        @stop = true
      end

      # Fetches messages for a given controller in an endless loop
      # @param [Proc] action block that we want to call upon each message arrival
      # @yieldreturn [Karafka::Connection::Message] incoming message
      # @note It will stop gracefuly if stop! send to this listener
      # @example Run this loop asynchronously and stop
      #   listener.async.fetch_loop(block) && listener.async.stop!
      def fetch_loop(action)
        loop do
          break if stop?

          fetch(action)
        end
      end

      private

      # Opens connection, gets messages bulk and calls a block for each of the incoming messages
      # After everything is done, consumer connection is being closed so it cannot be used again
      # @param [Proc] action block that we want to call upon message arrival
      # @yieldreturn [Karafka::Connection::Message] incoming message
      # @note We use proc instead of direct block (yield) because of celluloid - it does not
      #   support blocks
      # Since Poseidon socket has a timeout (10 000ms by default) we catch it and ignore,
      #   we will just reconnect again
      def fetch(action)
        Karafka.logger.info("Fetching: #{controller.topic}")

        consumer.fetch_loop do |_partition, messages_bulk|
          Karafka.logger.info("Received #{messages_bulk.count} messages from #{controller.topic}")

          messages_bulk.each do |incoming_message|
            action.call(message(incoming_message))
          end
        end
      rescue *IGNORED_ERRORS => e
        Karafka.logger.debug("An ignored error occur in #{self.class}")
        Karafka.logger.debug(e)
      end

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

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single topic
    # @note It does not loop on itself - it needs to be executed in a loop
    # @note Listener itself does nothing with the message - it will return to the block
    #   a raw Poseidon::FetchedMessage
    class Listener
      attr_reader :controller

      # @param controller [Karafka::BaseController] a descendant of base controller
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(controller)
        @controller = controller
      end

      # Opens connection, gets messages bulk and calls a block for each of the incoming messages
      # After everything is done, queue_consumer connection is being closed so
      #   it cannot be used again
      # @yieldparam [Karafka::BaseController] base controller descendant
      # @yieldparam [Poseidon::FetchedMessage] poseidon fetched message
      # Since Poseidon socket has a timeout (10 000ms by default) we catch it and ignore,
      #   we will just reconnect again
      # @note This will yield with a raw message - no preprocessing or reformatting
      # @note We catch all the errors here, so they don't affect other listeners (or this one)
      #   so we will be able to listen and consume other incoming messages.
      #   Since it is run inside Karafka::Connection::Cluster - catching all the exceptions won't
      #   crash the whole cluster. Here we mostly focus on catchin the exceptions related to
      #   Kafka connections / Internet connection issues / Etc. Business logic problems should not
      #   propagate this far
      def fetch(block)
        Karafka.logger.info("Fetching: #{controller.topic}")

        queue_consumer.fetch do |_partition, messages_bulk|
          Karafka.logger.info("Received #{messages_bulk.count} messages from #{controller.topic}")

          messages_bulk.each do |raw_message|
            block.call(controller, raw_message)
          end
        end
        # rubocop:enable RescueException
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        # @see https://github.com/bsm/poseidon_cluster/issues/20
        if e.is_a? Poseidon::Errors::ProtocolError
          @queue_consumer.close
          @queue_consumer = nil
        end

        Karafka.logger.error("An error occur in #{self.class}")
        Karafka.logger.error(e)
      end

      private

      # @return [Karafka::Connection::QueueConsumer] queue consumer that listens to a topic
      # @note This is not a Karafka::Connection::Consumer
      def queue_consumer
        @queue_consumer ||= QueueConsumer.new(@controller)
      end
    end
  end
end

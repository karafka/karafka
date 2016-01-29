module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single route
    # @note It does not loop on itself - it needs to be executed in a loop
    # @note Listener itself does nothing with the message - it will return to the block
    #   a raw Poseidon::FetchedMessage
    class Listener
      attr_reader :route

      # @return [Karafka::Connection::Listener] listener instance
      def initialize(route)
        @route = route
      end

      # Opens connection, gets messages bulk and calls a block for each of the incoming messages
      # @yieldparam [Karafka::BaseController] base controller descendant
      # @yieldparam [Poseidon::FetchedMessage] poseidon fetched message
      # @return [Poseidon::FetchedMessage] last message that was processed. Keep in mind that
      #   this might not mean last message from the message bulk. We might stop processing in the
      #   middle of the bulk if for example restart is triggered, etc
      # Since Poseidon socket has a timeout (10 000ms by default) we catch it and ignore,
      #   we will just reconnect again
      # @note This will yield with a raw message - no preprocessing or reformatting
      # @note We catch all the errors here, so they don't affect other listeners (or this one)
      #   so we will be able to listen and consume other incoming messages.
      #   Since it is run inside Karafka::Connection::ActorCluster - catching all the exceptions
      #   won't crash the whole cluster. Here we mostly focus on catchin the exceptions related to
      #   Kafka connections / Internet connection issues / Etc. Business logic problems should not
      #   propagate this far
      def fetch(block)
        # Fetch provides us with additional informations
        # It will be set to false if we couldn't clame connection
        # So if it is not claimed, we should try again with a new connection
        queue_consumer.fetch do |_partition, messages_bulk|
          Karafka.monitor.notice(
            self.class,
            topic: route.topic,
            message_count: messages_bulk.count
          )

          messages_bulk.each do |raw_message|
            block.call(raw_message)
            # We check this for each message because application might be set for shutdown
            # or restart. Then we stop processing messages that we received, we return
            # last processed message and based on that queue consumer will commit the offset
            # in place where we've finished. That way after restarting, we will start from
            # the place where we've ended
            return raw_message unless Karafka::App.running?
          end

          messages_bulk.last
        end
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self.class, e)
      end

      private

      # @return [Karafka::Connection::QueueConsumer] queue consumer that listens to a route
      # @note This is not a Karafka::Connection::Consumer
      def queue_consumer
        @queue_consumer ||= QueueConsumer.new(@route)
      end
    end
  end
end

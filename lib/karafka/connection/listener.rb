module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single route
    # @note It does not loop on itself - it needs to be executed in a loop
    # @note Listener itself does nothing with the message - it will return to the block
    #   a raw Kafka::FetchedMessage
    class Listener
      include Celluloid

      execute_block_on_receiver :fetch_loop

      attr_reader :route

      # @return [Karafka::Connection::Listener] listener instance
      def initialize(route)
        @route = route
      end

      # Opens connection, gets messages and calls a block for each of the incoming messages
      # @yieldparam [Karafka::BaseController] base controller descendant
      # @yieldparam [Kafka::FetchedMessage] kafka fetched message
      # @note This will yield with a raw message - no preprocessing or reformatting
      # @note We catch all the errors here, so they don't affect other listeners (or this one)
      #   so we will be able to listen and consume other incoming messages.
      #   Since it is run inside Karafka::Connection::ActorCluster - catching all the exceptions
      #   won't crash the whole cluster. Here we mostly focus on catchin the exceptions related to
      #   Kafka connections / Internet connection issues / Etc. Business logic problems should not
      #   propagate this far
      def fetch_loop(block)
        topic_consumer.fetch_loop do |raw_message|
          block.call(raw_message)
        end
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self.class, e)
        @topic_consumer&.stop
        retry if @topic_consumer
      end

      private

      # @return [Karafka::Connection::TopicConsumer] wrapped kafka consumer for a given topic
      #   consumption
      # @note It adds consumer into Karafka::Server consumers pool for graceful shutdown on exit
      def topic_consumer
        @topic_consumer ||= TopicConsumer.new(@route).tap do |consumer|
          Karafka::Server.consumers << consumer if Karafka::Server.consumers
        end
      end
    end
  end
end

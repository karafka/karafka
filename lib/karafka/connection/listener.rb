# frozen_string_literal: true

module Karafka
  module Connection
    # A single listener that listens to incoming messages from a single route
    # @note It does not loop on itself - it needs to be executed in a loop
    # @note Listener itself does nothing with the message - it will return to the block
    #   a raw Kafka::FetchedMessage
    class Listener
      # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group that holds details
      #   on what topics and with what settings should we listen
      # @return [Karafka::Connection::Listener] listener instance
      def initialize(consumer_group)
        @consumer_group = consumer_group
      end

      # Runs prefetch callbacks and executes the main listener fetch loop
      def call
        Karafka::Callbacks.before_fetch_loop(
          @consumer_group,
          client
        )
        fetch_loop
      end

      private

      # Opens connection, gets messages and calls a block for each of the incoming messages
      # @yieldparam [String] consumer group id
      # @yieldparam [Array<Kafka::FetchedMessage>] kafka fetched messages
      # @note This will yield with a raw message - no preprocessing or reformatting
      # @note We catch all the errors here, so they don't affect other listeners (or this one)
      #   so we will be able to listen and consume other incoming messages.
      #   Since it is run inside Karafka::Connection::ActorCluster - catching all the exceptions
      #   won't crash the whole cluster. Here we mostly focus on catchin the exceptions related to
      #   Kafka connections / Internet connection issues / Etc. Business logic problems should not
      #   propagate this far
      def fetch_loop
        client.fetch_loop do |raw_messages|
          # @note What happens here is a delegation of processing to a proper processor based
          #   on the incoming messages characteristics
          Karafka::Connection::Delegator.call(@consumer_group.id, raw_messages)
        end
        # This is on purpose - see the notes for this method
        # rubocop:disable RescueException
      rescue Exception => e
        Karafka.monitor.instrument('connection.listener.fetch_loop.error', caller: self, error: e)
        # rubocop:enable RescueException
        @client.stop
        sleep(@consumer_group.reconnect_timeout) && retry
      end

      # @return [Karafka::Connection::Client] wrapped kafka consuming client for a given topic
      #   consumption
      def client
        @client ||= Client.new(@consumer_group)
      end
    end
  end
end

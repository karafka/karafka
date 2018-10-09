# frozen_string_literal: true

module Karafka
  module Connection
    # Class used as a wrapper around Ruby-Kafka client to simplify additional
    # features that we provide/might provide in future and to hide the internal implementation
    class Client
      extend Forwardable

      def_delegator :kafka_consumer, :seek

      # Creates a queue consumer client that will pull the data from Kafka
      # @param consumer_group [Karafka::Routing::ConsumerGroup] consumer group for which
      #   we create a client
      # @return [Karafka::Connection::Client] group consumer that can subscribe to
      #   multiple topics
      def initialize(consumer_group)
        @consumer_group = consumer_group
        Persistence::Client.write(self)
      end

      # Opens connection, gets messages and calls a block for each of the incoming messages
      # @yieldparam [Array<Kafka::FetchedMessage>] kafka fetched messages
      # @note This will yield with raw messages - no preprocessing or reformatting.
      def fetch_loop
        settings = ApiAdapter.consumption(consumer_group)

        if consumer_group.batch_fetching
          kafka_consumer.each_batch(*settings) { |batch| yield(batch.messages) }
        else
          # always yield an array of messages, so we have consistent API (always a batch)
          kafka_consumer.each_message(*settings) { |message| yield([message]) }
        end
      rescue Kafka::ProcessingError => error
        # If there was an error during consumption, we have to log it, pause current partition
        # and process other things
        Karafka.monitor.instrument(
          'connection.client.fetch_loop.error',
          caller: self,
          error: error.cause
        )
        pause(error.topic, error.partition)
        retry
      end

      # Gracefuly stops topic consumption
      # @note Stopping running consumers without a really important reason is not recommended
      #   as until all the consumers are stopped, the server will keep running serving only
      #   part of the messages
      def stop
        @kafka_consumer&.stop
        @kafka_consumer = nil
      end

      # Pauses fetching and consumption of a given topic partition
      # @param topic [String] topic that we want to pause
      # @param partition [Integer] number partition that we want to pause
      def pause(topic, partition)
        kafka_consumer.pause(*ApiAdapter.pause(topic, partition, consumer_group))
      end

      # Marks a given message as consumed and commit the offsets
      # @note In opposite to ruby-kafka, we commit the offset for each manual marking to be sure
      #   that offset commit happen asap in case of a crash
      # @param [Karafka::Params::Params] params message that we want to mark as processed
      def mark_as_consumed(params)
        kafka_consumer.mark_message_as_processed(
          *ApiAdapter.mark_message_as_processed(params)
        )
        # Trigger an immediate, blocking offset commit in order to minimize the risk of crashing
        # before the automatic triggers have kicked in.
        kafka_consumer.commit_offsets
      end

      # Triggers a non-optional blocking heartbeat that notifies Kafka about the fact, that this
      # consumer / client is still up and running
      def trigger_heartbeat
        kafka_consumer.trigger_heartbeat!
      end

      private

      attr_reader :consumer_group

      # @return [Kafka::Consumer] returns a ready to consume Kafka consumer
      #   that is set up to consume from topics of a given consumer group
      def kafka_consumer
        # @note We don't cache the connection internally because we cache kafka_consumer that uses
        #   kafka client object instance
        @kafka_consumer ||= Builder.call.consumer(
          *ApiAdapter.consumer(consumer_group)
        ).tap do |consumer|
          consumer_group.topics.each do |topic|
            consumer.subscribe(*ApiAdapter.subscribe(topic))
          end
        end
      rescue Kafka::ConnectionError
        # If we would not wait it would totally spam log file with failed
        # attempts if Kafka is down
        sleep(consumer_group.reconnect_timeout)
        # We don't log and just reraise - this will be logged
        # down the road
        raise
      end
    end
  end
end

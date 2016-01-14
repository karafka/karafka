module Karafka
  module Connection
    # Class used as a wrapper around Poseidon::ConsumerGroup to simplify additional
    # features that we provide/might provide in future
    class QueueConsumer
      # Connection socket default timeout
      SOCKET_TIMEOUT_MS = 11_000
      # Offset between socket timeout and wait timeout - there needs to be
      # gap between those two values so we won't raise socket timeouts when
      # we just want to close the connection because nothing is going on
      TIMEOUT_OFFSET = 1_000

      # Errors on which we close the connection and reconnect again
      # They happen when something is wrong on Kafka/Zookeeper side or when
      # some timeout/network issues happen
      CONNECTION_CLEAR_ERRORS = [
        Poseidon::Connection::ConnectionFailedError,
        Poseidon::Errors::ProtocolError,
        Poseidon::Errors::UnableToFetchMetadata,
        ZK::Exceptions::KeeperException,
        Zookeeper::Exceptions::ZookeeperException
      ]

      # How long should it wait until trying to rebalance again
      CLAIM_SLEEP_TIME = 1

      # Creates a queue consumer that will pull the data from Kafka
      # @param controller [Karafka::BaseController] base controller descendant
      # @return [Karafka::Connection::QueueConsumer] queue consumer instance
      def initialize(controller)
        @controller = controller
      end

      # Fetches a bulk of messages from Kafka and yield a block with them
      # @param options [Hash] additional options for fetching
      # @yield [partition, message_bulk] Yields code providing partition details and message bulk
      # @yieldparam partition [Integer] number of Kafka partition
      # @yieldparam message_bulk [Array<Poseidon::FetchedMessage>] array with fetched messages
      # @example
      #   consumer.fetch do |partition, messages|
      #      puts "Processing partition: #{partition}"
      #      puts "#{messages.count} messages received"
      #   end
      # @note If something went wrong during fetch, it will log in and close current connection
      #   so a new one will be created during next fetch
      def fetch(options = {})
        claimed = target.fetch(options) do |partition, message_bulk|
          yield(partition, message_bulk)
        end

        # In order not to produce infinite number of errors, when we cannot claim any partitions
        # lets just wait and try again later - maybe someone else
        return if claimed

        close
        sleep(CLAIM_SLEEP_TIME)
      rescue *CONNECTION_CLEAR_ERRORS => e
        Karafka.monitor.notice_error(self.class, e)
        close
      end

      private

      # @return [Poseidon::ConsumerGroup] consumer group instance
      def target
        @target ||= Poseidon::ConsumerGroup.new(
          @controller.group.to_s,
          ::Karafka::App.config.kafka_hosts,
          ::Karafka::App.config.zookeeper_hosts,
          @controller.topic.to_s,
          socket_timeout_ms: SOCKET_TIMEOUT_MS,
          # How long should we wait for messages if nothing is there to process
          # @note This must be smaller than SOCKET_TIMEOUT_MS so we won't raise
          #   constantly socket timeout errors
          max_wait_ms: SOCKET_TIMEOUT_MS - TIMEOUT_OFFSET
        )
      rescue *CONNECTION_CLEAR_ERRORS => e
        Karafka.monitor.notice_error(self.class, e)
        close
      end

      # If something is wrong with the connection, it will try to
      # trigger reload and will close it
      def close
        return unless @target

        target.reload
        target.close
      rescue *CONNECTION_CLEAR_ERRORS => e
        Karafka.monitor.notice_error(self.class, e)
      ensure
        @target = nil
      end
    end
  end
end

module Karafka
  module Connection
    # Class used as a wrapper around Poseidon::ConsumerGroup to simplify additional
    # features that we provide/might provide in future
    class QueueConsumer
      # Offset between socket timeout and wait timeout - there needs to be
      # gap between those two values so we won't raise socket timeouts when
      # we just want to close the connection because nothing is going on
      TIMEOUT_OFFSET = 1

      # Errors on which we close the connection and reconnect again
      # They happen when something is wrong on Kafka/Zookeeper side or when
      # some timeout/network issues happen
      CONNECTION_CLEAR_ERRORS = [
        Poseidon::Connection::ConnectionFailedError,
        Poseidon::Errors::ProtocolError,
        Poseidon::Errors::UnableToFetchMetadata,
        ZK::Exceptions::KeeperException,
        Zookeeper::Exceptions::ZookeeperException
      ].freeze

      # How long should it wait until trying to rebalance again
      CLAIM_SLEEP_TIME = 1

      # Creates a queue consumer that will pull the data from Kafka
      # @param [Karafka::Routing::Route] route details that will be used to build up a
      #   queue consumer instance
      # @return [Karafka::Connection::QueueConsumer] queue consumer instance
      def initialize(route)
        @route = route
      end

      # Fetches a bulk of messages from Kafka and yield a block with them
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
      # @note The block that is being yielded needs to return last processed message as a return
      #   value, because we need that information in order to commit the offset
      def fetch
        claimed = target.fetch(commit: false) do |partition, message_bulk|
          last_processed_message = yield(partition, message_bulk)
          commit(partition, last_processed_message)
        end

        # In order not to produce infinite number of errors, when we cannot claim any partitions
        # lets just wait and try again later - maybe someone else will release it
        # Otherwise (if claimed) we just stop. We don't close connection or anything because we
        # are connected and can receive data
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
          @route.group,
          ::Karafka::App.config.kafka.hosts,
          ::Karafka::App.config.zookeeper.hosts,
          @route.topic,
          socket_timeout_ms: (::Karafka::App.config.wait_timeout + TIMEOUT_OFFSET) * 1000,
          # How long should we wait for messages if nothing is there to process
          # @note This must be smaller than socket_timeout_ms so we won't raise
          #   constantly socket timeout errors. Also we use a seconds value, meanwhile
          #   Poseidon requires a ms value - that's why we multiply by 1000
          max_wait_ms: ::Karafka::App.config.wait_timeout * 1000
        )
      rescue *CONNECTION_CLEAR_ERRORS => e
        Karafka.monitor.notice_error(self.class, e)
        close
      end

      # Commits offset to Kafka
      # We should commit offset only when we've consumed all the messages, otherwise if the process
      # is killed, we won't be able to get messages that were not processed yet (sent via socket)
      # @param partition [Integer] Number of partition from which we were consuming messages
      # @param last_processed_message [Poseidon::FetchedMessage] last message that we've
      #   successfully processed
      # @note By processed we mean passing it through the controller and scheduling it to be
      #   handled by the worker. Then we can consider data to be "saved" since it is being stored
      #   in Redis and will be handled in a background job
      # @note Most of the time, this method will be scheduled on a last message that we've received
      #   from Kafka, but there are some cases (graceful shutdown, restart) when we will stop
      #   processing fetched messages, return last that we've managed to handle and exit
      # @note It is also worth pointing out, that if we kill Karafka process during the data
      #   processing, this method won't be executed, offset won't be commited and we will have to
      #   process last messages bulk again
      def commit(partition, last_processed_message)
        return unless last_processed_message

        target.commit partition, last_processed_message.offset + 1
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

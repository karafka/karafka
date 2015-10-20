module Karafka
  module Connection
    # Class used as a wrapper around Poseidon::ConsumerGroup to simplify additional
    # features that we provide/might provide in future
    class QueueConsumer < Poseidon::ConsumerGroup
      # Connection socket default timeout
      SOCKET_TIMEOUT_MS = 11_000
      # Offset between socket timeout and wait timeout - there needs to be
      # gap between those two values so we won't raise socket timeouts when
      # we just want to close the connection because nothing is going on
      TIMEOUT_OFFSET = 1_000
      # How long should we wait for messages if nothing is there to process
      # @note This must be smaller than SOCKET_TIMEOUT_MS so we won't raise
      #   constantly socket timeout errors
      MAX_WAIT_MS = SOCKET_TIMEOUT_MS - TIMEOUT_OFFSET

      # Creates a queue consumer that will pull the data from Kafka
      # @param controller [Karafka::BaseController] base controller descendant
      # @return [Karafka::Connection::QueueConsumer] queue consumer instance
      def initialize(controller)
        super(
          controller.group.to_s,
          ::Karafka::App.config.kafka_hosts,
          ::Karafka::App.config.zookeeper_hosts,
          controller.topic.to_s,
          socket_timeout_ms: SOCKET_TIMEOUT_MS,
          max_wait_ms: MAX_WAIT_MS
        )
      end
    end
  end
end

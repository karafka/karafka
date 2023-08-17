# frozen_string_literal: true

module Karafka
  module Connection
    # Usually it is ok to use the `Rdkafka::Consumer` directly because we need 1:1 its
    # functionality. There are however cases where we want to have extra recoveries or other
    # handling of errors and settings. This is where this module comes in handy.
    #
    # We do not want to wrap and delegate all via a proxy object for performance reasons, but we
    # do still want to be able to alter some functionalities. This wrapper helps us do it when
    # it would be needed
    class Proxy < SimpleDelegator
      # Timeout on the watermark query
      WATERMARK_REQUEST_TIMEOUT = 5_000

      # Timeout on the TPL request query
      TPL_REQUEST_TIMEOUT = 5_000

      # How many attempts we want to take for something that would end up with all_brokers_down
      BROKERS_DOWN_MAX_ATTEMPTS = 3

      # How long should we wait in between all_brokers_down
      BROKERS_DOWN_BACKOFF_TIME = 1

      private_constant :WATERMARK_REQUEST_TIMEOUT, :BROKERS_DOWN_MAX_ATTEMPTS,
                       :BROKERS_DOWN_BACKOFF_TIME, :TPL_REQUEST_TIMEOUT

      attr_accessor :wrapped
      alias_method :__getobj__, :wrapped

      def initialize(obj)
        # Do not allow for wrapping proxy with a proxy. This will prevent a case where we might
        # wrap an already wrapped object with another proxy level. Simplifies passing consumers
        # and makes it self to wrap without type checking
        @wrapped = obj.is_a?(self.class) ? obj.wrapped : obj
      end

      # Proxies the `#query_watermark_offsets` with extra recovery from timeout problems.
      # We impose our own custom timeout to make sure, that high-latency clusters and overloaded
      # clusters can handle our requests.
      #
      # @param topic [String] topic name
      # @param partition [Partition]
      # @return [Array<Integer, Integer>] watermark offsets
      def query_watermark_offsets(topic, partition)
        with_brokers_down_retry do
          @wrapped.query_watermark_offsets(
            topic,
            partition,
            WATERMARK_REQUEST_TIMEOUT
          )
        end
      end

      # Similar to `#query_watermark_offsets`, this method can be sensitive to latency. We handle
      # this the same way
      #
      # @param tpl [Rdkafka::Consumer::TopicPartitionList] tpl to get time offsets
      # @return [Rdkafka::Consumer::TopicPartitionList] tpl with time offsets
      def offsets_for_times(tpl)
        with_brokers_down_retry do
          @wrapped.offsets_for_times(tpl, TPL_REQUEST_TIMEOUT)
        end
      end

      private

      # Runs expected block of code with few retries on all_brokers_down
      # librdkafka can return `all_brokers_down` for scenarios when broker is overloaded or not
      # reachable due to latency.
      def with_brokers_down_retry
        attempt ||= 0
        attempt += 1

        yield
      rescue Rdkafka::RdkafkaError => e
        raise if e.code != :all_brokers_down

        if attempt <= BROKERS_DOWN_MAX_ATTEMPTS
          sleep(BROKERS_DOWN_BACKOFF_TIME)

          retry
        end

        raise
      end
    end
  end
end

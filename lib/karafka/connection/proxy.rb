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
      # Errors on which we want to retry
      RETRYABLE_ERRORS = %i[
        all_brokers_down
        timed_out
      ].freeze

      private_constant :RETRYABLE_ERRORS

      attr_accessor :wrapped

      alias __getobj__ wrapped

      # @param obj [Rdkafka::Consumer, Proxy] rdkafka consumer or consumer wrapped with proxy
      def initialize(obj)
        super
        # Do not allow for wrapping proxy with a proxy. This will prevent a case where we might
        # wrap an already wrapped object with another proxy level. Simplifies passing consumers
        # and makes it safe to wrap without type checking
        @wrapped = obj.is_a?(self.class) ? obj.wrapped : obj
        @config = ::Karafka::App.config.internal.connection.proxy
      end

      # Proxies the `#query_watermark_offsets` with extra recovery from timeout problems.
      # We impose our own custom timeout to make sure, that high-latency clusters and overloaded
      # clusters can handle our requests.
      #
      # @param topic [String] topic name
      # @param partition [Partition]
      # @return [Array<Integer, Integer>] watermark offsets
      def query_watermark_offsets(topic, partition)
        l_config = @config.query_watermark_offsets

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: l_config.wait_time / 1_000.to_f,
          max_attempts: l_config.max_attempts
        ) do
          @wrapped.query_watermark_offsets(topic, partition, l_config.timeout)
        end
      end

      # Similar to `#query_watermark_offsets`, this method can be sensitive to latency. We handle
      # this the same way
      #
      # @param tpl [Rdkafka::Consumer::TopicPartitionList] tpl to get time offsets
      # @return [Rdkafka::Consumer::TopicPartitionList] tpl with time offsets
      def offsets_for_times(tpl)
        l_config = @config.offsets_for_times

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: l_config.wait_time / 1_000.to_f,
          max_attempts: l_config.max_attempts
        ) do
          @wrapped.offsets_for_times(tpl, l_config.timeout)
        end
      end

      # Similar to `#query_watermark_offsets`.
      #
      # @param tpl [Rdkafka::Consumer::TopicPartitionList, nil] tpl or nil for full current
      #   assignment tpl usage
      # @return [Rdkafka::Consumer::TopicPartitionList] tpl with committed offsets and metadata
      def committed(tpl = nil)
        c_config = @config.committed

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: c_config.wait_time / 1_000.to_f,
          max_attempts: c_config.max_attempts
        ) do
          @wrapped.committed(tpl, c_config.timeout)
        end
      end

      # When we cannot store an offset, it means we no longer own the partition
      #
      # Non thread-safe offset storing method
      # @param message [Karafka::Messages::Message]
      # @param metadata [String, nil] offset storage metadata or nil if none
      # @return [Boolean] true if we could store the offset (if we still own the partition)
      def store_offset(message, metadata = nil)
        @wrapped.store_offset(message, metadata)

        true
      rescue Rdkafka::RdkafkaError => e
        return false if e.code == :assignment_lost
        return false if e.code == :state

        raise e
      end

      # Non thread-safe message committing method
      # @param async [Boolean] should the commit happen async or sync (async by default)
      # @return [Boolean] true if offset commit worked, false if we've lost the assignment
      # @note We do **not** consider `no_offset` as any problem and we allow to commit offsets
      #   even when no stored, because with sync commit, it refreshes the ownership state of the
      #   consumer in a sync way.
      def commit_offsets(async: true)
        @wrapped.commit(nil, async)

        true
      rescue Rdkafka::RdkafkaError => e
        case e.code
        when :assignment_lost
          return false
        when :unknown_member_id
          return false
        when :no_offset
          return true
        when :coordinator_load_in_progress
          sleep(1)
          retry
        end

        raise e
      end

      private

      # Runs expected block of code with few retries on all_brokers_down
      # librdkafka can return `all_brokers_down` for scenarios when broker is overloaded or not
      # reachable due to latency.
      # @param max_attempts [Integer] how many attempts (not retries) should we take before failing
      #   completely.
      # @param wait_time [Integer, Float] how many seconds should we wait. It uses `#sleep` of Ruby
      #   so it needs time in seconds.
      def with_broker_errors_retry(max_attempts:, wait_time: 1)
        attempt ||= 0
        attempt += 1

        yield
      rescue Rdkafka::RdkafkaError => e
        raise unless RETRYABLE_ERRORS.include?(e.code)

        if attempt <= max_attempts
          sleep(wait_time)

          retry
        end

        raise
      end
    end
  end
end

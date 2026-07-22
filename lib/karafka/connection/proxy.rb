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
      include Helpers::ConfigImporter.new(
        proxy_config: %i[internal connection proxy]
      )

      # Errors on which we want to retry
      # Includes temporary errors related to node not being (or not yet being) coordinator or a
      # leader to a given set of partitions. Usually goes away after a retry
      RETRYABLE_DEFAULT_ERRORS = %i[
        all_brokers_down
        timed_out
        transport
        network_exception
        not_coordinator
        not_leader_for_partition
        coordinator_load_in_progress
        stale_member_epoch
      ].freeze

      private_constant :RETRYABLE_DEFAULT_ERRORS

      attr_accessor :wrapped

      alias_method :__getobj__, :wrapped

      # @param obj [Rdkafka::Consumer, Proxy] rdkafka consumer or consumer wrapped with proxy
      def initialize(obj)
        super
        # Do not allow for wrapping proxy with a proxy. This will prevent a case where we might
        # wrap an already wrapped object with another proxy level. Simplifies passing consumers
        # and makes it safe to wrap without type checking
        @wrapped = obj.is_a?(self.class) ? obj.wrapped : obj
      end

      # Proxies the `#query_watermark_offsets` with extra recovery from timeout problems.
      # We impose our own custom timeout to make sure, that high-latency clusters and overloaded
      # clusters can handle our requests.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Array<Integer, Integer>] watermark offsets
      def query_watermark_offsets(topic, partition)
        l_config = proxy_config.query_watermark_offsets

        # For newly created topics or in cases where we're trying to get them but there is no
        # leader, this can fail. It happens more often for new topics under KRaft, however we
        # still want to make sure things operate as expected even then
        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: l_config.wait_time / 1_000.to_f,
          max_attempts: l_config.max_attempts
        ) do
          @wrapped.query_watermark_offsets(topic, partition, l_config.timeout)
        end
      end

      # Resolves offsets of many partitions with one batched `ListOffsets` request instead of one
      # roundtrip per partition. This is the same broker query as `#query_watermark_offsets`,
      # only batched, so it is sensitive to the same latencies and leader-election hiccups and we
      # recover from them the same way and with the same settings.
      #
      # Named after `Admin::Topics#read_partition_offsets` (same specs in, same offsets out) and
      # **not** after the underlying `#list_offsets`, so we do not shadow the rdkafka method of
      # that name: it returns a handle to wait on, while we return the already resolved offsets.
      #
      # @param topic_partition_offsets [Hash{String => Array<Hash>}] topics with arrays of
      #   partition offset specs, each with a `:partition` and an `:offset` (`:earliest`,
      #   `:latest`, `:max_timestamp` or an integer timestamp in ms)
      # @param isolation_level [Integer, nil] isolation level with which the offsets should be
      #   resolved or nil for the librdkafka default (read_uncommitted)
      # @return [Array<Hash>] resolved offsets, each with `:topic`, `:partition` and `:offset`
      # @note The `ListOffsets` admin API resolves `:latest` to the high watermark even with
      #   `isolation_level` set to read_committed, unlike `#query_watermark_offsets`, which returns
      #   the last stable offset for a read_committed consumer. On a topic with an in-flight
      #   transaction `:latest` therefore includes the uncommitted messages. Non-transactional
      #   topics are unaffected.
      # @note Specs given as a literal hash need explicit curly braces: a brace-less trailing
      #   hash is parsed by Ruby as keyword arguments, which this method (having the
      #   `isolation_level:` keyword) would reject as a missing positional argument
      def read_partition_offsets(topic_partition_offsets, isolation_level: nil)
        l_config = proxy_config.query_watermark_offsets

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: l_config.wait_time / 1_000.to_f,
          max_attempts: l_config.max_attempts
        ) do
          @wrapped
            .list_offsets(topic_partition_offsets, isolation_level: isolation_level)
            .wait(max_wait_timeout_ms: l_config.timeout)
            .offsets
        rescue Rdkafka::AbstractHandle::WaitTimeoutError
          # Align with the error contract of the per-partition watermark query, so a slow broker
          # is retried here instead of escaping as a handle wait timeout
          raise Rdkafka::RdkafkaError.new(
            Rdkafka::Bindings::RD_KAFKA_RESP_ERR__TIMED_OUT,
            "Error querying offsets of '#{topic_partition_offsets.keys.join(", ")}'"
          )
        end
      end

      # Similar to `#query_watermark_offsets`, this method can be sensitive to latency. We handle
      # this the same way
      #
      # @param tpl [Rdkafka::Consumer::TopicPartitionList] tpl to get time offsets
      # @return [Rdkafka::Consumer::TopicPartitionList] tpl with time offsets
      def offsets_for_times(tpl)
        l_config = proxy_config.offsets_for_times

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
        c_config = proxy_config.committed

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
        return false if e.code == :illegal_generation

        raise e
      end

      # Non thread-safe message committing method
      # @param tpl [Rdkafka::Consumer::TopicPartitionList, nil] tpl or nil
      # @param async [Boolean] should the commit happen async or sync (async by default)
      # @return [Boolean] true if offset commit worked, false if we've lost the assignment
      # @note We do **not** consider `no_offset` as any problem and we allow to commit offsets
      #   even when no stored, because with sync commit, it refreshes the ownership state of the
      #   consumer in a sync way.
      def commit_offsets(tpl = nil, async: true)
        c_config = proxy_config.commit

        with_broker_errors_retry(
          wait_time: c_config.wait_time / 1_000.to_f,
          max_attempts: c_config.max_attempts
        ) do
          @wrapped.commit(tpl, async)
        end

        true
      rescue Rdkafka::RdkafkaError => e
        case e.code
        when :assignment_lost
          return false
        when :unknown_member_id
          return false
        when :illegal_generation
          return false
        when :no_offset
          return true
        when :coordinator_load_in_progress
          sleep(1)
          retry
        end

        raise e
      end

      # @param tpl [Rdkafka::Consumer::TopicPartitionList] list of topics and partitions for which
      #   we want to get the lag on the defined CG
      # @return [Hash{String => Hash}] hash with topics and their partitions lags
      def lag(tpl)
        l_config = proxy_config.committed

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: l_config.wait_time / 1_000.to_f,
          max_attempts: l_config.max_attempts
        ) do
          @wrapped.lag(tpl, l_config.timeout)
        end
      end

      # @param topic_name [String, nil] Name of the topic we're interested in or nil if we want to
      #   get info on all topics
      # @return [Rdkafka::Metadata] rdkafka metadata object with the requested details
      def metadata(topic_name = nil)
        m_config = proxy_config.metadata

        with_broker_errors_retry(
          # required to be in seconds, not ms
          wait_time: m_config.wait_time / 1_000.to_f,
          max_attempts: m_config.max_attempts
        ) do
          @wrapped.metadata(topic_name, m_config.timeout)
        end
      end

      private

      # Runs expected block of code with few retries on all_brokers_down
      # librdkafka can return `all_brokers_down` for scenarios when broker is overloaded or not
      # reachable due to latency.
      # @param max_attempts [Integer] how many attempts (not retries) should we take before failing
      #   completely.
      # @param wait_time [Integer, Float] how many seconds should we wait. It uses `#sleep` of Ruby
      #   so it needs time in seconds.
      # @param errors [Array<Symbol>] rdkafka errors we want to retry on
      def with_broker_errors_retry(max_attempts:, wait_time: 1, errors: RETRYABLE_DEFAULT_ERRORS)
        attempt ||= 0
        attempt += 1

        yield
      rescue Rdkafka::RdkafkaError => e
        raise unless errors.include?(e.code)

        if attempt <= max_attempts
          sleep(wait_time)

          retry
        end

        raise
      end
    end
  end
end

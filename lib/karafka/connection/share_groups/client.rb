# frozen_string_literal: true

module Karafka
  module Connection
    # Share-group (KIP-932) connection components. Parallel to {Connection::ConsumerGroups}, this
    # namespace holds the runtime pieces specific to share groups ("Queues for Kafka").
    module ShareGroups
      # An abstraction layer on top of the rdkafka share consumer.
      #
      # Unlike {Connection::ConsumerGroups::Client} it has no offset/seek/pause/assign/rebalance
      # machinery: share consumers acquire individual records under time-bounded leases and
      # acknowledge them per record (accept/release/reject) instead of committing partition
      # offsets. The underlying `Rdkafka::ShareConsumer` is single-threaded by design and services
      # its log, statistics and error callbacks from within `#poll`.
      #
      # @note This client is not thread-safe for concurrent polling. It is driven by a single
      #   share-group listener thread (the tight poll-process-acknowledge loop).
      class Client
        include Karafka::Core::Helpers::Time
        include Helpers::ConfigImporter.new(
          logger: %i[logger],
          shutdown_timeout: %i[shutdown_timeout]
        )

        # Shared frozen empty result reused for empty/failed polls to avoid allocations
        EMPTY_ARRAY = [].freeze

        private_constant :EMPTY_ARRAY

        # @return [Karafka::Routing::SubscriptionGroup] subscription group to which this client
        #   belongs
        attr_reader :subscription_group

        # @return [String] underlying rdkafka client name (may be blank until the share handle
        #   reports it via a callback)
        attr_reader :name

        # @return [String] id of the client
        attr_reader :id

        # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group with
        #   all the configuration details needed for us to create a share client
        def initialize(subscription_group)
          @id = SecureRandom.hex(6)
          @name = ""
          @closed = false
          @subscription_group = subscription_group
          @mutex = Mutex.new
        end

        # Fetches a batch of records within the given time budget.
        #
        # librdkafka's share poll returns a batch of already-acquired records (possibly spanning
        # partitions). Callbacks (statistics/error) are serviced as part of this call.
        #
        # @param timeout [Integer] max time in milliseconds to wait for records
        # @return [Array<Rdkafka::ShareConsumer::Message>] fetched records (may be empty)
        def batch_poll(timeout = @subscription_group.max_wait_time)
          result = kafka.poll(timeout)

          return EMPTY_ARRAY if result.nil? || result.empty?

          messages = []

          result.each do |item|
            # A record that fails to build is surfaced inline as an error object rather than
            # aborting the whole batch. We report it and skip it; the broker will redeliver it
            # after its acquisition lock expires since it never gets acknowledged.
            if item.is_a?(Rdkafka::RdkafkaError)
              Karafka.monitor.instrument(
                "error.occurred",
                caller: self,
                error: item,
                type: "connection.client.poll.error"
              )
            else
              messages << item
            end
          end

          messages
        rescue Rdkafka::RdkafkaError => e
          Karafka.monitor.instrument(
            "error.occurred",
            caller: self,
            error: e,
            type: "connection.client.poll.error"
          )

          # Fatal errors will not recover, so we re-raise and let the listener reset the client.
          # Non-fatal errors (transient broker/network issues, unknown topic while it is being
          # created) are swallowed - the next poll retries and any unacknowledged record is
          # redelivered by the broker after its lock expires.
          raise if e.fatal?

          EMPTY_ARRAY
        end

        # Acknowledges a single record as successfully consumed (ACCEPT). Mirrors the consumer-group
        # client's `#mark_as_consumed` naming so both modes share the same positive-ack convention;
        # the record will not be redelivered.
        #
        # @param message [Karafka::Messages::Message] message to acknowledge. It responds to
        #   `#topic`, `#partition` and `#offset`, which is what the acknowledgement needs.
        def mark_as_consumed(message)
          acknowledge(message, :accept)
        end

        alias_method :mark_consumed, :mark_as_consumed

        # Releases a single record back to the share group for redelivery (RELEASE). `mark_released`
        # is provided as a shorter alias.
        #
        # @param message [Karafka::Messages::Message] message to release
        def mark_as_released(message)
          acknowledge(message, :release)
        end

        alias_method :mark_released, :mark_as_released

        # Rejects a single record so it is not redelivered (REJECT). `mark_rejected` is provided as
        # a shorter alias.
        #
        # @param message [Karafka::Messages::Message] message to reject
        def mark_as_rejected(message)
          acknowledge(message, :reject)
        end

        alias_method :mark_rejected, :mark_as_rejected

        # Flushes pending acknowledgements to the broker in a non-blocking or blocking way.
        #
        # Mirrors the consumer-group client's `#commit_offsets` convention (async by default, with a
        # blocking `#commit!` variant); share groups flush acknowledgements rather than offsets, so
        # the method is named `#commit`.
        #
        # @param async [Boolean] should the commit happen async (default) or sync
        def commit(async: true)
          async ? kafka.commit_async : kafka.commit_sync
        rescue Rdkafka::RdkafkaError => e
          Karafka.monitor.instrument(
            "error.occurred",
            caller: self,
            error: e,
            type: "connection.client.commit.error"
          )

          raise if e.fatal?

          false
        end

        # Flushes pending acknowledgements in a synchronous (blocking) way.
        #
        # @see #commit
        def commit!
          commit(async: false)
        end

        # Gracefully stops the client: flushes outstanding acknowledgements and closes.
        #
        # Unlike a consumer-group client there is no assignment to drain or unsubscribe dance -
        # share groups have no partition ownership.
        def stop
          commit(async: false) if @kafka && !@closed
        rescue Rdkafka::RdkafkaError
          nil
        ensure
          close
        end

        # Closes the client and removes the registered rdkafka callbacks.
        def close
          @mutex.synchronize do
            return if @closed

            @closed = true

            return unless @kafka

            sg_id = @subscription_group.id

            Karafka::Core::Instrumentation.statistics_callbacks.delete(sg_id)
            Karafka::Core::Instrumentation.error_callbacks.delete(sg_id)
            Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(sg_id)

            kafka.close
            @kafka = nil
          end
        end

        # @return [Boolean] true if the client is closed
        def closed?
          @closed
        end

        # Closes the current share consumer and allows a fresh one to be built on the next poll.
        # Used by the listener to recover from errors and to re-open after a stop.
        def reset
          close

          @mutex.synchronize { @closed = false }
        end

        private

        # Acknowledges a single record with the given state.
        #
        # @param message [Karafka::Messages::Message] message to acknowledge
        # @param state [Symbol] `:accept`, `:release` or `:reject`
        def acknowledge(message, state)
          kafka.acknowledge(message, state)
        end

        # @return [Rdkafka::ShareConsumer] librdkafka share consumer instance
        def kafka
          return @kafka if @kafka

          @kafka = build_consumer
        end

        # Builds a new rdkafka share consumer based on the subscription group configuration and
        # subscribes it to the group's topics.
        #
        # @return [Rdkafka::ShareConsumer]
        def build_consumer
          Rdkafka::Config.logger = logger

          # Refresh in case we started running in a swarm (static membership mapping etc.), same
          # as the consumer-group client.
          @subscription_group.refresh

          config = Rdkafka::Config.new(@subscription_group.kafka)

          # The share consumer creates and registers its native handle immediately; there is no
          # separate `#start` and no rebalance listener (share assignment is fully broker-driven).
          consumer = config.share_consumer
          @name = consumer.name

          Karafka::Core::Instrumentation.statistics_callbacks.add(
            @subscription_group.id,
            Instrumentation::Callbacks::ShareGroups::Statistics.new(
              @subscription_group.id,
              @subscription_group.group.id,
              @name
            )
          )

          Karafka::Core::Instrumentation.error_callbacks.add(
            @subscription_group.id,
            Instrumentation::Callbacks::ShareGroups::Error.new(
              @subscription_group.id,
              @subscription_group.group.id,
              @name
            )
          )

          Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.add(
            @subscription_group.id,
            Instrumentation::Callbacks::OauthbearerTokenRefresh.new(
              consumer
            )
          )

          consumer.subscribe(*@subscription_group.subscriptions)

          consumer
        rescue
          # Mirror the consumer-group client cleanup: if anything past allocation raises, drop the
          # callback registry entries and destroy the native handle so it does not leak.
          sg_id = @subscription_group.id
          Karafka::Core::Instrumentation.statistics_callbacks.delete(sg_id)
          Karafka::Core::Instrumentation.error_callbacks.delete(sg_id)
          Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(sg_id)

          begin
            consumer&.close
          rescue
            nil
          end

          raise
        end
      end
    end
  end
end

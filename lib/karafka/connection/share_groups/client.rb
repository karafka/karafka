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
      # @note The underlying share consumer allows only one caller at a time: for example an
      #   `#acknowledge` from one worker while another worker is in a synchronous commit raises
      #   `conflict`. Since acknowledgements and commits run from many worker threads, every call
      #   that touches the native handle is serialized with a mutex.
      class Client
        include Karafka::Core::Helpers::Time
        include Helpers::ConfigImporter.new(
          logger: %i[logger],
          shutdown_timeout: %i[shutdown_timeout],
          tick_interval: %i[internal tick_interval]
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
        # @param batch_poll_breaker [Proc] proc that when evaluated to false will cause the batch
        #   poll to finish early. Like for consumer groups, this allows us to stop without waiting
        #   for a long poll to finish.
        def initialize(subscription_group, batch_poll_breaker = -> { true })
          @id = SecureRandom.hex(6)
          @name = ""
          @closed = false
          @subscription_group = subscription_group
          @mutex = Mutex.new
          # Records delivered by the last poll that were not acknowledged yet. In the explicit
          # acknowledgement mode librdkafka refuses to poll again until every one of them is
          # acknowledged, so we need to know which are still outstanding.
          @pending = {}

          # Like for consumer groups, while waiting for records we service the events queue and
          # check if we should stop with the tick frequency
          @interval_runner = Helpers::IntervalRunner.new do
            events_poll
            batch_poll_breaker.call ? :run : :stop
          end
        end

        # Fetches a batch of records within the given time budget.
        #
        # librdkafka's share poll returns a batch of already-acquired records (possibly spanning
        # partitions). Like for consumer groups, a single native poll never runs longer than the
        # tick interval, so while waiting for records the events queue (statistics, errors) is
        # serviced and a stop request ends the poll early instead of waiting for `max_wait_time`.
        #
        # @param timeout [Integer] max time in milliseconds to wait for records
        # @return [Array<Rdkafka::ShareConsumer::Message>] fetched records (may be empty)
        def batch_poll(timeout = @subscription_group.max_wait_time)
          time_poll = TimeTrackers::Poll.new(timeout)
          result = nil

          loop do
            time_poll.start

            poll_tick = [time_poll.remaining, tick_interval].min
            result = @mutex.synchronize { kafka.poll(poll_tick) }

            time_poll.checkpoint

            break unless result.nil? || result.empty?
            break if time_poll.exceeded?
            break if @interval_runner.call == :stop
          end

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

          @mutex.synchronize do
            messages.each { |message| @pending[pending_key(message)] = message }
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

        # Triggers the rdkafka main queue events by servicing it. This is not the share record
        # acquisition queue but the one with:
        #   - error callbacks
        #   - stats callbacks
        #   - OAuthBearer token refresh callbacks
        #
        # Unlike {#batch_poll} this does not acquire any share records, so it can be used to keep
        # the callbacks flowing while we are not polling for records (waiting on in-flight work,
        # quieting or draining on shutdown) - mirroring the consumer-group client.
        #
        # @param timeout [Integer] number of milliseconds to wait on events or 0 not to wait.
        # @param safe [Boolean] when true, rescues Rdkafka::RdkafkaError so callers in
        #   shutdown/quiet paths do not trigger a full listener reset.
        def events_poll(timeout = 0, safe: false)
          @mutex.synchronize do
            # Do not service (nor rebuild) the consumer once closed
            return if @closed

            kafka.events_poll(timeout)
          end

          Karafka.monitor.instrument(
            "client.events_poll",
            caller: self,
            subscription_group: @subscription_group
          )
        rescue Rdkafka::RdkafkaError
          safe ? nil : raise
        end

        # Acknowledges a single record as accepted (ACCEPT / successfully processed). The record
        # will not be redelivered.
        #
        # @param message [Karafka::Messages::Message] message to acknowledge. It responds to
        #   `#topic`, `#partition` and `#offset`, which is what the acknowledgement needs.
        def mark_as_accepted(message)
          acknowledge(message, :accept)
        end

        # Releases a single record back to the share group for redelivery (RELEASE).
        #
        # @param message [Karafka::Messages::Message] message to release
        def mark_as_released(message)
          acknowledge(message, :release)
        end

        # Rejects a single record so it is not redelivered (REJECT).
        #
        # @param message [Karafka::Messages::Message] message to reject
        def mark_as_rejected(message)
          acknowledge(message, :reject)
        end

        # @param message [Karafka::Messages::Message] record from the last poll
        # @return [Boolean] is the record still not acknowledged
        def pending?(message)
          @mutex.synchronize { @pending.key?(pending_key(message)) }
        end

        # Acknowledges with the given state every record of `messages` that was not acknowledged
        # yet. Used to settle a processed batch so that no record is left outstanding.
        #
        # @param messages [Array<Karafka::Messages::Message>] processed records (raw array, not the
        #   `Messages` batch, so external `#each` patches are not triggered)
        # @param state [Symbol] `:accept`, `:release` or `:reject`
        def settle(messages, state)
          @mutex.synchronize do
            return if @closed

            messages.each do |message|
              key = pending_key(message)

              next unless @pending.key?(key)

              kafka.acknowledge(message, state)
              @pending.delete(key)
            end
          end
        end

        # Releases every record that is still not acknowledged, so the next poll can proceed. This
        # is a safety net - processed batches are settled by the processing strategies.
        #
        # @return [Integer] number of released records
        def release_pending
          @mutex.synchronize do
            return 0 if @closed || @pending.empty?

            released = @pending.size
            @pending.each_value { |message| kafka.acknowledge(message, :release) }
            @pending.clear

            released
          end
        end

        # Flushes pending acknowledgements to the broker in a non-blocking or blocking way.
        #
        # Mirrors the consumer-group client's `#commit_offsets` convention (async by default, with a
        # blocking `#commit!` variant); share groups flush acknowledgements rather than offsets, so
        # the method is named `#commit`. Errors propagate to the caller and surface through the
        # regular error flow (the same way consumer-group commit errors do), rather than a
        # dedicated error event.
        #
        # @param async [Boolean] should the commit happen async (default) or sync
        def commit(async: true)
          @mutex.synchronize do
            # Do not flush (nor rebuild the consumer) once closed. Any record left unacknowledged
            # is redelivered by the broker after its acquisition lock expires.
            return if @closed

            async ? kafka.commit_async : kafka.commit_sync
          end
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
            # Closing the share consumer releases whatever it still holds
            @pending.clear

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
          Karafka.monitor.instrument(
            "client.reset",
            caller: self,
            subscription_group: @subscription_group
          ) do
            close

            @mutex.synchronize { @closed = false }
          end
        end

        private

        # Acknowledges a single record with the given state.
        #
        # @param message [Karafka::Messages::Message] message to acknowledge
        # @param state [Symbol] `:accept`, `:release` or `:reject`
        def acknowledge(message, state)
          @mutex.synchronize do
            # Do not acknowledge (nor rebuild the consumer) once closed. The record is redelivered
            # by the broker after its acquisition lock expires.
            return if @closed

            kafka.acknowledge(message, state)
            @pending.delete(pending_key(message))
          end
        end

        # @param message [Karafka::Messages::Message, Rdkafka::ShareConsumer::Message] record
        # @return [Array] key identifying the record within the share group
        def pending_key(message)
          [message.topic, message.partition, message.offset]
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

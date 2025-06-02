# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # An abstraction layer on top of the rdkafka consumer.
    #
    # It is threadsafe and provides some security measures so we won't end up operating on a
    # closed consumer instance as it causes Ruby VM process to crash.
    class Client
      include ::Karafka::Core::Helpers::Time
      include Helpers::ConfigImporter.new(
        logger: %i[logger],
        tick_interval: %i[internal tick_interval],
        shutdown_timeout: %i[shutdown_timeout]
      )

      attr_reader :rebalance_manager

      # @return [Karafka::Routing::SubscriptionGroup] subscription group to which this client
      #   belongs to
      attr_reader :subscription_group

      # @return [String] underlying consumer name
      # @note Consumer name may change in case we regenerate it
      attr_reader :name

      # @return [String] id of the client
      attr_reader :id

      # How many times should we retry polling in case of a failure
      MAX_POLL_RETRIES = 20

      # How much time of the total shutdown time can we wait for our manual unsubscribe before
      # attempting to close without unsubscribe. We try to wait for 50% of the shutdown time
      # before we move to a regular unsubscribe.
      COOP_UNSUBSCRIBE_FACTOR = 0.5

      # Errors upon which we early report that something is off without retrying prior to the
      # report
      EARLY_REPORT_ERRORS = [
        :inconsistent_group_protocol, # 23
        :max_poll_exceeded, # -147
        :network_exception, # 13
        :transport, # -195
        :topic_authorization_failed, # 29
        :group_authorization_failed, # 30
        :cluster_authorization_failed, # 31
        :illegal_generation,
        # this will not recover as fencing is permanent
        :fenced, # -144
        # This can happen for many reasons, including issues with static membership being fenced
        :fatal # -150
      ].freeze

      private_constant :MAX_POLL_RETRIES, :COOP_UNSUBSCRIBE_FACTOR, :EARLY_REPORT_ERRORS

      # Creates a new consumer instance.
      #
      # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group
      #   with all the configuration details needed for us to create a client
      # @param batch_poll_breaker [Proc] proc that when evaluated to false will cause the batch
      #   poll loop to finish early. This improves the shutdown and dynamic multiplication as it
      #   allows us to early break on long polls.
      # @return [Karafka::Connection::Client]
      def initialize(subscription_group, batch_poll_breaker)
        @id = SecureRandom.hex(6)
        # Name is set when we build consumer
        @name = ''
        @closed = false
        @subscription_group = subscription_group
        @buffer = RawMessagesBuffer.new
        @rebalance_manager = RebalanceManager.new(@subscription_group.id, @buffer)
        @rebalance_callback = Instrumentation::Callbacks::Rebalance.new(@subscription_group, id)

        @interval_runner = Helpers::IntervalRunner.new do
          events_poll
          # events poller returns nil when not running often enough, hence we don't use the
          # boolean to be explicit
          batch_poll_breaker.call ? :run : :stop
        end

        # There are few operations that can happen in parallel from the listener threads as well
        # as from the workers. They are not fully thread-safe because they may be composed out of
        # few calls to Kafka or out of few internal state changes. That is why we mutex them.
        # It mostly revolves around pausing and resuming.
        @mutex = Mutex.new
        # We need to keep track of what we have paused for resuming
        # In case we loose partition, we still need to resume it, otherwise it won't be fetched
        # again if we get reassigned to it later on. We need to keep them as after revocation we
        # no longer may be able to fetch them from Kafka. We could build them but it is easier
        # to just keep them here and use if needed when cannot be obtained
        @paused_tpls = Hash.new { |h, k| h[k] = {} }
      end

      # Fetches messages within boundaries defined by the settings (time, size, topics, etc).
      #
      # Also periodically runs the events polling to trigger events callbacks.
      #
      # @return [Karafka::Connection::MessagesBuffer] messages buffer that holds messages per topic
      #   partition
      # @note This method should not be executed from many threads at the same time
      def batch_poll
        time_poll = TimeTrackers::Poll.new(@subscription_group.max_wait_time)

        @buffer.clear
        @rebalance_manager.clear

        events_poll

        loop do
          time_poll.start

          # Don't fetch more messages if we do not have any time left
          break if time_poll.exceeded?
          # Don't fetch more messages if we've fetched max that we've wanted
          break if @buffer.size >= @subscription_group.max_messages

          # Fetch message within our time boundaries
          response = poll(time_poll.remaining)

          # We track when last polling happened so we can provide means to detect upcoming
          # `max.poll.interval.ms` limit
          @buffer.polled

          case response
          when :tick_time
            nil
          # We get a hash only in case of eof error
          when Hash
            @buffer.eof(response[:topic], response[:partition])
          when nil
            nil
          else
            @buffer << response
          end

          # Upon polling rebalance manager might have been updated.
          # If partition revocation happens, we need to remove messages from revoked partitions
          # as well as ensure we do not have duplicated due to the offset reset for partitions
          # that we got assigned
          #
          # We also do early break, so the information about rebalance is used as soon as possible
          if @rebalance_manager.changed?
            # Since rebalances do not occur often, we can run events polling as well without
            # any throttling
            events_poll

            break
          end

          # If we were signaled from the outside to break the loop, we should
          break if @interval_runner.call == :stop

          # Track time spent on all of the processing and polling
          time_poll.checkpoint

          # Finally once we've (potentially) removed revoked, etc, if no messages were returned
          # and it was not an early poll exist, we can break. We also break if we got the eof
          # signaling to propagate it asap
          # Worth keeping in mind, that the rebalance manager might have been updated despite no
          # messages being returned during a poll
          break if response.nil? || response.is_a?(Hash)
        end

        @buffer
      end

      # Stores offset for a given partition of a given topic based on the provided message.
      #
      # @param message [Karafka::Messages::Message]
      # @param offset_metadata [String, nil] offset storage metadata or nil if none
      def store_offset(message, offset_metadata = nil)
        internal_store_offset(message, offset_metadata)
      end

      # @return [Boolean] true if our current assignment has been lost involuntarily.
      def assignment_lost?
        kafka.assignment_lost?
      end

      # @return [Rdkafka::Consumer::TopicPartitionList] current active assignment
      def assignment
        kafka.assignment
      end

      # Commits the offset on a current consumer in a non-blocking or blocking way.
      #
      # @param async [Boolean] should the commit happen async or sync (async by default)
      # @return [Boolean] did committing was successful. It may be not, when we no longer own
      #   given partition.
      #
      # @note This will commit all the offsets for the whole consumer. In order to achieve
      #   granular control over where the offset should be for particular topic partitions, the
      #   store_offset should be used to only store new offset when we want them to be flushed
      #
      # @note This method for async may return `true` despite involuntary partition revocation as
      #   it does **not** resolve to `lost_assignment?`. It returns only the commit state operation
      #   result.
      def commit_offsets(async: true)
        internal_commit_offsets(async: async)
      end

      # Commits offset in a synchronous way.
      #
      # @see `#commit_offset` for more details
      def commit_offsets!
        commit_offsets(async: false)
      end

      # Seek to a particular message. The next poll on the topic/partition will return the
      # message at the given offset.
      #
      # @param message [Messages::Message, Messages::Seek] message to which we want to seek to.
      #   It can have the time based offset.
      # @note Please note, that if you are seeking to a time offset, getting the offset is blocking
      def seek(message)
        @mutex.synchronize { internal_seek(message) }
      end

      # Pauses given partition and moves back to last successful offset processed.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition
      # @param offset [Integer, nil] offset of the message on which we want to pause (this message
      #   will be reprocessed after getting back to processing) or nil if we want to pause and
      #   resume from the consecutive offset (+1 from the last message passed to us by librdkafka)
      # @param timeout [Integer] number of ms timeout of pause. It is used only for
      #   instrumentation and not in the pause itself as pausing on this level is infinite always.
      # @note This will pause indefinitely and requires manual `#resume`
      # @note When `#internal_seek` is not involved (when offset is `nil`) we will not purge the
      #   librdkafka buffers and continue from the last cursor offset
      # @note We accept the timeout value on this layer to have a cohesive pause/resume
      #   instrumentation, where all the details are available. It is especially needed, when
      def pause(topic, partition, offset = nil, timeout = 0)
        @mutex.synchronize do
          # Do not pause if the client got closed, would not change anything
          return if @closed

          internal_commit_offsets(async: true)

          # Here we do not use our cached tpls because we should not try to pause something we do
          # not own anymore.
          tpl = topic_partition_list(topic, partition)

          return unless tpl

          Karafka.monitor.instrument(
            'client.pause',
            caller: self,
            subscription_group: @subscription_group,
            topic: topic,
            partition: partition,
            offset: offset,
            timeout: timeout
          )

          @paused_tpls[topic][partition] = tpl

          kafka.pause(tpl)

          # If offset is not provided, will pause where it finished.
          # This makes librdkafka not purge buffers and can provide significant network savings
          # when we just want to pause before further processing without changing the offsets
          return unless offset

          pause_msg = Messages::Seek.new(topic, partition, offset)

          internal_seek(pause_msg)
        end
      end

      # Resumes processing of a give topic partition after it was paused.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition
      def resume(topic, partition)
        @mutex.synchronize do
          return if @closed

          # We now commit offsets on rebalances, thus we can do it async just to make sure
          internal_commit_offsets(async: true)

          # If we were not able, let's try to reuse the one we have (if we have)
          tpl = topic_partition_list(topic, partition) || @paused_tpls[topic][partition]

          return unless tpl

          # If we did not have it, it means we never paused this partition, thus no resume should
          # happen in the first place
          return unless @paused_tpls[topic].delete(partition)

          Karafka.monitor.instrument(
            'client.resume',
            caller: self,
            subscription_group: @subscription_group,
            topic: topic,
            partition: partition
          )

          kafka.resume(tpl)
        end
      end

      # Gracefully stops topic consumption.
      def stop
        # librdkafka has several constant issues when shutting down during rebalance. This is
        # an issue that gets back every few versions of librdkafka in a limited scope, for example
        # for cooperative-sticky or in a general scope. This is why we unsubscribe and wait until
        # we no longer have any assignments. That way librdkafka consumer shutdown should never
        # happen with rebalance associated with the given consumer instance. Since we do not want
        # to wait forever, we also impose a limit on how long should we wait. This prioritizes
        # shutdown stability over endless wait.
        #
        # The `@unsubscribing` ensures that when there would be a direct close attempt, it
        # won't get into this loop again. This can happen when supervision decides it should close
        # things faster
        #
        # @see https://github.com/confluentinc/librdkafka/issues/4792
        # @see https://github.com/confluentinc/librdkafka/issues/4527
        if unsubscribe?
          @unsubscribing = true

          # Give 50% of time for the final close before we reach the forceful
          max_wait = shutdown_timeout * COOP_UNSUBSCRIBE_FACTOR
          used = 0
          stopped_at = monotonic_now

          unsubscribe

          until assignment.empty?
            used += monotonic_now - stopped_at
            stopped_at = monotonic_now

            break if used >= max_wait

            sleep(0.1)

            ping
          end
        end

        close
      end

      # Marks given message as consumed.
      #
      # @param message [Karafka::Messages::Message] message that we want to mark as processed
      # @param metadata [String, nil] offset storage metadata or nil if none
      # @return [Boolean] true if successful. False if we no longer own given partition
      # @note This method won't trigger automatic offsets commits, rather relying on the offset
      #   check-pointing trigger that happens with each batch processed. It will however check the
      #   `librdkafka` assignment ownership to increase accuracy for involuntary revocations.
      def mark_as_consumed(message, metadata = nil)
        store_offset(message, metadata) && !assignment_lost?
      end

      # Marks a given message as consumed and commits the offsets in a blocking way.
      #
      # @param message [Karafka::Messages::Message] message that we want to mark as processed
      # @param metadata [String, nil] offset storage metadata or nil if none
      # @return [Boolean] true if successful. False if we no longer own given partition
      def mark_as_consumed!(message, metadata = nil)
        return false unless mark_as_consumed(message, metadata)

        commit_offsets!
      end

      # Closes and resets the client completely.
      def reset
        Karafka.monitor.instrument(
          'client.reset',
          caller: self,
          subscription_group: @subscription_group
        ) do
          close

          @interval_runner.reset
          @closed = false
          @paused_tpls.clear
        end
      end

      # Runs a single poll on the main queue and consumer queue ignoring all the potential errors
      # This is used as a keep-alive in the shutdown stage and any errors that happen here are
      # irrelevant from the shutdown process perspective
      #
      # This is used only to trigger rebalance callbacks and other callbacks
      def ping
        events_poll(100)
        poll(100)
      rescue Rdkafka::RdkafkaError
        nil
      end

      # Triggers the rdkafka main queue events by consuming this queue. This is not the consumer
      # consumption queue but the one with:
      #   - error callbacks
      #   - stats callbacks
      #   - OAUTHBEARER token refresh callbacks
      #
      # @param timeout [Integer] number of milliseconds to wait on events or 0 not to wait.
      #
      # @note It is non-blocking when timeout 0 and will not wait if queue empty. It costs up to
      #   2ms when no callbacks are triggered.
      def events_poll(timeout = 0)
        kafka.events_poll(timeout)
      end

      # Returns pointer to the consumer group metadata. It is used only in the context of
      # exactly-once-semantics in transactions, this is why it is never remapped to Ruby
      # @return [FFI::Pointer]
      def consumer_group_metadata_pointer
        kafka.consumer_group_metadata_pointer
      end

      # Return the current committed offset per partition for this consumer group.
      # The offset field of each requested partition will either be set to stored offset or to
      # -1001 in case there was no stored offset for that partition.
      #
      # @param tpl [Rdkafka::Consumer::TopicPartitionList] for which we want to get committed
      # @return [Rdkafka::Consumer::TopicPartitionList]
      # @raise [Rdkafka::RdkafkaError] When getting the committed positions fails.
      # @note It is recommended to use this only on rebalances to get positions with metadata
      #   when working with metadata as this is synchronous
      def committed(tpl = nil)
        @wrapped_kafka.committed(tpl)
      end

      # Reads watermark offsets for given topic
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition number
      # @return [Array<Integer, Integer>] watermark offsets (low, high)
      def query_watermark_offsets(topic, partition)
        @wrapped_kafka.query_watermark_offsets(topic, partition)
      end

      private

      # When we cannot store an offset, it means we no longer own the partition
      #
      # Non thread-safe offset storing method
      # @param message [Karafka::Messages::Message]
      # @param metadata [String, nil] offset storage metadata or nil if none
      # @return [Boolean] true if we could store the offset (if we still own the partition)
      def internal_store_offset(message, metadata)
        @wrapped_kafka.store_offset(message, metadata)
      end

      # Non thread-safe message committing method
      # @param async [Boolean] should the commit happen async or sync (async by default)
      # @return [Boolean] true if offset commit worked, false if we've lost the assignment
      # @note We do **not** consider `no_offset` as any problem and we allow to commit offsets
      #   even when no stored, because with sync commit, it refreshes the ownership state of the
      #   consumer in a sync way.
      def internal_commit_offsets(async: true)
        @wrapped_kafka.commit_offsets(async: async)
      end

      # Non-mutexed seek that should be used only internally. Outside we expose `#seek` that is
      # wrapped with a mutex.
      #
      # @param message [Messages::Message, Messages::Seek] message to which we want to seek to.
      #   It can have the time based offset.
      #
      # @note Will not invoke seeking if the desired seek would lead us to the current position.
      #   This prevents us from flushing librdkafka buffer when it is not needed.
      def internal_seek(message)
        # If the seek message offset is in a time format, we need to find the closest "real"
        # offset matching before we seek
        if message.offset.is_a?(Time)
          tpl = ::Rdkafka::Consumer::TopicPartitionList.new
          tpl.add_topic_and_partitions_with_offsets(
            message.topic,
            message.partition => message.offset
          )

          # Now we can overwrite the seek message offset with our resolved offset and we can
          # then seek to the appropriate message
          # We set the timeout to 2_000 to make sure that remote clusters handle this well
          real_offsets = @wrapped_kafka.offsets_for_times(tpl)
          # We always ask for one partition, so result will contain array with only one element
          # that is the partition we were interested it regardless its number
          detected_partition = real_offsets.to_h.dig(message.topic, 0)

          # There always needs to be an offset. In case we seek into the future, where there
          # are no offsets yet, we get -1 which indicates the most recent offset
          # We should always detect offset, whether it is 0, -1 or a corresponding
          message.offset = detected_partition&.offset || raise(Errors::InvalidTimeBasedOffsetError)
        end

        # Those two are librdkafka hardcoded values
        message.offset = -1 if message.offset.to_s == 'latest'
        message.offset = -2 if message.offset.to_s == 'earliest'

        # Never seek if we would get the same location as we would get without seeking
        # This prevents us from the expensive buffer purges that can lead to increased network
        # traffic and can cost a lot of money
        #
        # This code adds around 0.01 ms per seek but saves from many user unexpected behaviours in
        # seeking and pausing
        position = topic_partition_position(message.topic, message.partition)

        # Always seek if current position cannot be fetched or is negative. Offset seek can also
        # be negative (-1 or -2) and we should not compare it with the position because they are
        # special (earliest or latest)
        return kafka.seek(message) if position.negative?
        # If offset is the same as the next position, we don't have to seek to get there, hence
        # only in such case we can do nothing.
        return kafka.seek(message) if message.offset != position

        nil
      end

      # Commits the stored offsets in a sync way and closes the consumer.
      def close
        # Once client is closed, we should not close it again
        # This could only happen in case of a race-condition when forceful shutdown happens
        # and triggers this from a different thread
        return if @closed

        @closed = true

        return unless @kafka

        sg_id = @subscription_group.id

        # Remove callbacks runners that were registered
        ::Karafka::Core::Instrumentation.statistics_callbacks.delete(sg_id)
        ::Karafka::Core::Instrumentation.error_callbacks.delete(sg_id)
        ::Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.delete(sg_id)

        kafka.close
        @kafka = nil
        @wrapped_kafka = nil
        @buffer.clear
        # @note We do not clear rebalance manager here as we may still have revocation info
        # here that we want to consider valid prior to running another reconnection
      end

      # Unsubscribes from all the subscriptions
      # @note This is a private API to be used only on shutdown
      # @note We do not re-raise since this is supposed to be only used on close and can be safely
      #   ignored. We do however want to instrument on it
      def unsubscribe
        kafka.unsubscribe
      rescue ::Rdkafka::RdkafkaError => e
        Karafka.monitor.instrument(
          'error.occurred',
          caller: self,
          error: e,
          type: 'connection.client.unsubscribe.error'
        )
      end

      # @param topic [String]
      # @param partition [Integer]
      # @return [Rdkafka::Consumer::TopicPartitionList]
      def topic_partition_list(topic, partition)
        rdkafka_partition = kafka
                            .assignment
                            .to_h[topic]
                            &.detect { |part| part.partition == partition }

        return unless rdkafka_partition

        Rdkafka::Consumer::TopicPartitionList.new({ topic => [rdkafka_partition] })
      end

      # @param topic [String]
      # @param partition [Integer]
      # @return [Integer] current position within topic partition or `-1` if it could not be
      #   established. It may be `-1` in case we lost the assignment or we did not yet fetch data
      #   for this topic partition
      def topic_partition_position(topic, partition)
        rd_partition = ::Rdkafka::Consumer::Partition.new(partition, nil, 0)
        tpl = ::Rdkafka::Consumer::TopicPartitionList.new(topic => [rd_partition])

        kafka.position(tpl).to_h.fetch(topic).first.offset || -1
      end

      # Performs a single poll operation and handles retries and errors
      #
      # Keep in mind, that this timeout will be limited by a tick interval value, because we cannot
      # block on a single poll longer than that. Otherwise our events polling would not be able to
      # run frequently enough. This means, that even if you provide big value, it will not block
      # for that long. This is anyhow compensated by the `#batch_poll` that can run for extended
      # period of time but will run events polling frequently while waiting for the requested total
      # time.
      #
      # @param timeout [Integer] timeout for a single poll.
      # @return [Rdkafka::Consumer::Message, nil, Symbol] fetched message, nil if nothing polled
      #   within the time we had or symbol indicating the early return reason
      def poll(timeout)
        time_poll ||= TimeTrackers::Poll.new(timeout)

        return nil if time_poll.exceeded?

        time_poll.start
        remaining = time_poll.remaining

        # We should not run a single poll longer than the tick frequency. Otherwise during a single
        # `#batch_poll` we would not be able to run `#events_poll` often enough effectively
        # blocking events from being handled.
        poll_tick = timeout > tick_interval ? tick_interval : timeout

        result = kafka.poll(poll_tick)

        # If we've got a message, we can return it
        return result if result

        time_poll.checkpoint

        # We need to check if we have used all the allocated time as depending on the outcome, the
        # batch loop behavior will differ. Using all time means, that we had nothing to do as no
        # messages were present but if we did not exceed total time, it means we can still try
        # polling again as we are withing user expected max wait time
        used = remaining - time_poll.remaining

        # In case we did not use enough time, it means that an internal event occured that means
        # that something has changed without messages being published. For example a rebalance.
        # In cases like this we finish early as well
        return nil if used < poll_tick

        # If we did not exceed total time allocated, it means that we finished because of the
        # tick interval time limitations and not because time run out without any data
        time_poll.exceeded? ? nil : :tick_time
      rescue ::Rdkafka::RdkafkaError => e
        early_report = false

        retryable = time_poll.attempts <= MAX_POLL_RETRIES && time_poll.retryable?

        # There are retryable issues on which we want to report fast as they are source of
        # problems and can mean some bigger system instabilities
        # Those are mainly network issues and exceeding the max poll interval
        # We want to report early on max poll interval exceeding because it may mean that the
        # underlying processing is taking too much time and it is not LRJ
        case e.code
        when *EARLY_REPORT_ERRORS
          early_report = true
        # @see
        # https://github.com/confluentinc/confluent-kafka-dotnet/issues/1366#issuecomment-821842990
        # This will be raised each time poll detects a non-existing topic. When auto creation is
        # on, we can safely ignore it
        when :unknown_topic_or_part # 3
          return nil if @subscription_group.kafka[:'allow.auto.create.topics']

          early_report = true

          # No sense in retrying when no topic/partition and we're no longer running
          retryable = false unless Karafka::App.running?
        # If we detect the end of partition which can happen if `enable.partition.eof` is set to
        # true, we can just return fast. This will fast yield whatever set of messages we
        # already have instead of waiting. This can be used for better latency control when we do
        # not expect a lof of lag and want to quickly move to processing.
        # We can also pass the eof notion to the consumers for improved decision making.
        when :partition_eof
          return e.details
        end

        if early_report || !retryable
          Karafka.monitor.instrument(
            'error.occurred',
            caller: self,
            error: e,
            type: 'connection.client.poll.error'
          )
        end

        raise unless retryable

        # Most of the errors can be safely ignored as librdkafka will recover from them
        # @see https://github.com/edenhill/librdkafka/issues/1987#issuecomment-422008750
        # @see https://github.com/edenhill/librdkafka/wiki/Error-handling

        time_poll.checkpoint
        time_poll.backoff

        # poll may not only return message but also can run callbacks and if they changed,
        # despite the errors we need to delegate to the other app parts
        @rebalance_manager.changed? ? nil : retry
      end

      # Builds a new rdkafka consumer instance based on the subscription group configuration
      # @return [Rdkafka::Consumer]
      def build_consumer
        ::Rdkafka::Config.logger = logger

        # We need to refresh the setup of this subscription group in case we started running in a
        # swarm. The initial configuration for validation comes from the parent node, but it needs
        # to be altered in case of a static group membership usage for correct mapping of the
        # group instance id.
        @subscription_group.refresh

        config = ::Rdkafka::Config.new(@subscription_group.kafka)
        config.consumer_rebalance_listener = @rebalance_callback
        # We want to manage the events queue independently from the messages queue. Thanks to that
        # we can ensure, that we get statistics and errors often enough even when not polling
        # new messages. This allows us to report statistics while data is still being processed
        config.consumer_poll_set = false

        # Do not start native kafka so we can inject the oauth bearer callbacks if needed
        consumer = config.consumer(native_kafka_auto_start: false)
        @name = consumer.name

        # Register statistics runner for this particular type of callbacks
        ::Karafka::Core::Instrumentation.statistics_callbacks.add(
          @subscription_group.id,
          Instrumentation::Callbacks::Statistics.new(
            @subscription_group.id,
            @subscription_group.consumer_group.id,
            @name
          )
        )

        # Register error tracking callback
        ::Karafka::Core::Instrumentation.error_callbacks.add(
          @subscription_group.id,
          Instrumentation::Callbacks::Error.new(
            @subscription_group.id,
            @subscription_group.consumer_group.id,
            @name
          )
        )

        ::Karafka::Core::Instrumentation.oauthbearer_token_refresh_callbacks.add(
          @subscription_group.id,
          Instrumentation::Callbacks::OauthbearerTokenRefresh.new(
            consumer
          )
        )

        # Subscription needs to happen after we assigned the rebalance callbacks just in case of
        # a race condition
        subscriptions = @subscription_group.subscriptions
        assignments = @subscription_group.assignments(consumer)

        if subscriptions
          consumer.subscribe(*subscriptions)
          @mode = :subscribe
        elsif assignments
          consumer.assign(assignments)
          @mode = :assign
        end

        consumer
      end

      # @return [Rdkafka::Consumer] librdkafka consumer instance
      def kafka
        return @kafka if @kafka

        @kafka = build_consumer
        @wrapped_kafka = Proxy.new(@kafka)
        # We start it only after everything is configured so oauth or any other early-run client
        # related operations can occur. Otherwise, if all kafka referencing setup would not be
        # done, we could not intercept the invocations to kafka via client methods.
        @kafka.start
        @kafka
      end

      # Decides whether or not we should unsubscribe prior to closing.
      #
      # We cannot do it when there is a static group membership assignment as it would be
      # reassigned.
      # We cannot do it also for assign mode because then there are no subscriptions
      # We also do not do it if there are no assignments at all as it does not make sense
      #
      # @return [Boolean] should we unsubscribe prior to shutdown
      def unsubscribe?
        return false if @unsubscribing
        return false if @subscription_group.kafka.key?(:'group.instance.id')
        return false if @mode != :subscribe
        return false if assignment.empty?

        true
      end
    end
  end
end

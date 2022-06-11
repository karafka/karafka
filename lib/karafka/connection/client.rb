# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # An abstraction layer on top of the rdkafka consumer.
    #
    # It is threadsafe and provides some security measures so we won't end up operating on a
    # closed consumer instance as it causes Ruby VM process to crash.
    class Client
      attr_reader :rebalance_manager

      # @return [String] underlying consumer name
      # @note Consumer name may change in case we regenerate it
      attr_reader :name

      # How many times should we retry polling in case of a failure
      MAX_POLL_RETRIES = 10

      private_constant :MAX_POLL_RETRIES

      # Creates a new consumer instance.
      #
      # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group
      #   with all the configuration details needed for us to create a client
      # @return [Karafka::Connection::Rdk::Consumer]
      def initialize(subscription_group)
        # Name is set when we build consumer
        @name = ''
        @mutex = Mutex.new
        @closed = false
        @subscription_group = subscription_group
        @buffer = RawMessagesBuffer.new
        @rebalance_manager = RebalanceManager.new
        @kafka = build_consumer
        # Marks if we need to offset. If we did not store offsets, we should not commit the offset
        # position as it will crash rdkafka
        @offsetting = false
      end

      # Fetches messages within boundaries defined by the settings (time, size, topics, etc).
      #
      # @return [Karafka::Connection::MessagesBuffer] messages buffer that holds messages per topic
      #   partition
      # @note This method should not be executed from many threads at the same time
      def batch_poll
        time_poll = TimeTrackers::Poll.new(@subscription_group.max_wait_time)
        time_poll.start

        @buffer.clear
        @rebalance_manager.clear

        loop do
          # Don't fetch more messages if we do not have any time left
          break if time_poll.exceeded?
          # Don't fetch more messages if we've fetched max as we've wanted
          break if @buffer.size >= @subscription_group.max_messages

          # Fetch message within our time boundaries
          message = poll(time_poll.remaining)

          # Put a message to the buffer if there is one
          @buffer << message if message

          # Track time spent on all of the processing and polling
          time_poll.checkpoint

          # Upon polling rebalance manager might have been updated.
          # If partition revocation happens, we need to remove messages from revoked partitions
          # as well as ensure we do not have duplicated due to the offset reset for partitions
          # that we got assigned
          remove_revoked_and_duplicated_messages if @rebalance_manager.revoked_partitions?

          # Finally once we've (potentially) removed revoked, etc, if no messages were returned
          # we can break.
          # Worth keeping in mind, that the rebalance manager might have been updated despite no
          # messages being returned during a poll
          break unless message
        end

        @buffer
      end

      # Stores offset for a given partition of a given topic based on the provided message.
      #
      # @param message [Karafka::Messages::Message]
      def store_offset(message)
        @mutex.synchronize do
          internal_store_offset(message)
        end
      end

      # Commits the offset on a current consumer in a non-blocking or blocking way.
      # Ignoring a case where there would not be an offset (for example when rebalance occurs).
      #
      # @param async [Boolean] should the commit happen async or sync (async by default)
      # @return [Boolean] did committing was successful. It may be not, when we no longer own
      #   given partition.
      #
      # @note This will commit all the offsets for the whole consumer. In order to achieve
      #   granular control over where the offset should be for particular topic partitions, the
      #   store_offset should be used to only store new offset when we want to to be flushed
      def commit_offsets(async: true)
        @mutex.lock

        internal_commit_offsets(async: async)
      ensure
        @mutex.unlock
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
      # @param message [Messages::Message, Messages::Seek] message to which we want to seek to
      def seek(message)
        @mutex.lock

        @kafka.seek(message)
      ensure
        @mutex.unlock
      end

      # Pauses given partition and moves back to last successful offset processed.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition
      # @param offset [Integer] offset of the message on which we want to pause (this message will
      #   be reprocessed after getting back to processing)
      # @note This will pause indefinitely and requires manual `#resume`
      def pause(topic, partition, offset)
        @mutex.lock

        # Do not pause if the client got closed, would not change anything
        return if @closed

        pause_msg = Messages::Seek.new(topic, partition, offset)

        internal_commit_offsets(async: false)

        tpl = topic_partition_list(topic, partition)

        return unless tpl

        @kafka.pause(tpl)

        @kafka.seek(pause_msg)
      ensure
        @mutex.unlock
      end

      # Resumes processing of a give topic partition after it was paused.
      #
      # @param topic [String] topic name
      # @param partition [Integer] partition
      def resume(topic, partition)
        @mutex.lock

        return if @closed

        # Always commit synchronously offsets if any when we resume
        # This prevents resuming without offset in case it would not be committed prior
        # We can skip performance penalty since resuming should not happen too often
        internal_commit_offsets(async: false)

        tpl = topic_partition_list(topic, partition)

        return unless tpl

        @kafka.resume(tpl)
      ensure
        @mutex.unlock
      end

      # Gracefully stops topic consumption.
      #
      # @note Stopping running consumers without a really important reason is not recommended
      #   as until all the consumers are stopped, the server will keep running serving only
      #   part of the messages
      def stop
        close
      end

      # Marks given message as consumed.
      #
      # @param [Karafka::Messages::Message] message that we want to mark as processed
      # @note This method won't trigger automatic offsets commits, rather relying on the offset
      #   check-pointing trigger that happens with each batch processed
      def mark_as_consumed(message)
        store_offset(message)
      end

      # Marks a given message as consumed and commits the offsets in a blocking way.
      #
      # @param [Karafka::Messages::Message] message that we want to mark as processed
      def mark_as_consumed!(message)
        mark_as_consumed(message)
        commit_offsets!
      end

      # Closes and resets the client completely.
      def reset
        close

        @mutex.synchronize do
          @closed = false
          @offsetting = false
          @kafka = build_consumer
        end
      end

      private

      # Non thread-safe offset storing method
      # @param message [Karafka::Messages::Message]
      def internal_store_offset(message)
        @offsetting = true
        @kafka.store_offset(message)
      end

      # Non thread-safe message committing method
      # @param async [Boolean] should the commit happen async or sync (async by default)
      def internal_commit_offsets(async: true)
        return unless @offsetting

        @kafka.commit(nil, async)
        @offsetting = false
      rescue Rdkafka::RdkafkaError => e
        return if e.code == :no_offset

        raise e
      end

      # Commits the stored offsets in a sync way and closes the consumer.
      def close
        @mutex.synchronize do
          internal_commit_offsets(async: false)

          @closed = true

          # Remove callbacks runners that were registered
          ::Karafka::Instrumentation.statistics_callbacks.delete(@subscription_group.id)
          ::Karafka::Instrumentation.error_callbacks.delete(@subscription_group.id)

          @kafka.close
          @buffer.clear
          @rebalance_manager.clear
        end
      end

      # @param topic [String]
      # @param partition [Integer]
      # @return [Rdkafka::Consumer::TopicPartitionList]
      def topic_partition_list(topic, partition)
        rdkafka_partition = @kafka
                            .assignment
                            .to_h[topic]
                            &.detect { |part| part.partition == partition }

        return unless rdkafka_partition

        Rdkafka::Consumer::TopicPartitionList.new({ topic => [rdkafka_partition] })
      end

      # Performs a single poll operation.
      #
      # @param timeout [Integer] timeout for a single poll
      # @return [Rdkafka::Consumer::Message, nil] fetched message or nil if nothing polled
      def poll(timeout)
        time_poll ||= TimeTrackers::Poll.new(timeout)

        return nil if time_poll.exceeded?

        time_poll.start

        @kafka.poll(time_poll.remaining)
      rescue ::Rdkafka::RdkafkaError => e
        raise if time_poll.attempts > MAX_POLL_RETRIES
        raise unless time_poll.retryable?

        case e.code
        when :max_poll_exceeded # -147
          reset
        when :transport # -195
          reset
        when :rebalance_in_progress # -27
          reset
        when :not_coordinator # 16
          reset
        when :network_exception # 13
          reset
        end

        time_poll.checkpoint

        raise unless time_poll.retryable?

        time_poll.backoff

        retry
      end

      # Builds a new rdkafka consumer instance based on the subscription group configuration
      # @return [Rdkafka::Consumer]
      def build_consumer
        ::Rdkafka::Config.logger = ::Karafka::App.config.logger
        config = ::Rdkafka::Config.new(@subscription_group.kafka)
        config.consumer_rebalance_listener = @rebalance_manager
        consumer = config.consumer
        consumer.subscribe(*@subscription_group.topics.map(&:name))
        @name = consumer.name

        # Register statistics runner for this particular type of callbacks
        ::Karafka::Instrumentation.statistics_callbacks.add(
          @subscription_group.id,
          Instrumentation::Callbacks::Statistics.new(
            @subscription_group.id,
            @subscription_group.consumer_group_id,
            @name,
            ::Karafka::App.config.monitor
          )
        )

        # Register error tracking callback
        ::Karafka::Instrumentation.error_callbacks.add(
          @subscription_group.id,
          Instrumentation::Callbacks::Error.new(
            @subscription_group.id,
            @subscription_group.consumer_group_id,
            @name,
            ::Karafka::App.config.monitor
          )
        )

        consumer
      end

      # We may have a case where in the middle of data polling, we've lost a partition.
      # In a case like this we should remove all the pre-buffered messages from list partitions as
      # we are no longer responsible in a given process for processing those messages and they
      # should have been picked up by a different process.
      def remove_revoked_and_duplicated_messages
        @rebalance_manager.revoked_partitions.each do |topic, partitions|
          partitions.each do |partition|
            @buffer.delete(topic, partition)
          end
        end

        @buffer.uniq!
      end
    end
  end
end

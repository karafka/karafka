# frozen_string_literal: true

module Karafka
  module Consumers
    # Canonical consumer-group consumer. It carries all the consumer-group specific behavior:
    # offset management, pausing, seeking, partition eof and revocation handling and the
    # retry/backoff flow.
    #
    # It is also reachable via the legacy flat {Karafka::BaseConsumer} alias, which is kept for
    # backwards compatibility (it is the public base users subclass and Pro injects into it) and
    # is scheduled for retirement in Karafka 3.0.
    class ConsumerGroup < Base
      def_delegators :@coordinator, :eofed?, :seek_offset, :seek_offset=

      # @return [Symbol] group type
      def group_type
        :consumer
      end

      # Executes the default consumer flow.
      #
      # @private
      #
      # @return [Boolean] true if there was no exception, otherwise false.
      #
      # @note We keep the seek offset tracking, and use it to compensate for async offset flushing
      #   that may not yet kick in when error occurs. That way we pause always on the last processed
      #   message.
      def on_consume
        handle_consume
      # Containment is intentionally broader than StandardError: any error escaping this method
      # would bypass `#on_after_consume` in the worker, skipping the retry/pause flow entirely.
      # The next successful batch would then auto-mark its offsets, durably committing past the
      # failed batch - a silent at-least-once violation. Errors like SystemStackError or the
      # ScriptError family (e.g. LoadError surfacing from a Rails autoload hiccup) are per-message
      # failures and go through the regular retry flow like any other processing error.
      # Process-critical errors additionally trigger a graceful shutdown via the auto-subscribed
      # `Instrumentation::CriticalErrorsListener` watching this very instrumentation - the
      # recorded failure plus the retry pause keep this partition protected during the shutdown
      # window and the batch is redelivered after restart.
      rescue Exception => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          seek_offset: seek_offset,
          type: "consumer.consume.error"
        )
      end

      # @private
      #
      # @note This should not be used by the end users as it is part of the lifecycle of things but
      #   not as part of the public api.
      #
      # @note We handle and report errors here because of flows that could fail. For example a DLQ
      #   flow could fail if it was not able to dispatch the DLQ message. Other "non-user" based
      #   flows do not interact with external systems and their errors are expected to bubble up
      def on_after_consume
        handle_after_consume
      # Same containment rationale as in `#on_consume`: an error escaping this method would skip
      # the retry below and the next successful batch would auto-mark its offsets, committing
      # past the failed batch. The after-consume flow runs user-extensible code as well (DLQ
      # strategies, dispatch enhancements), so it needs the same class-agnostic protection
      rescue Exception => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          seek_offset: seek_offset,
          type: "consumer.after_consume.error"
        )

        retry_after_pause
      end

      # Can be used to run code prior to scheduling of eofed execution
      def on_before_schedule_eofed
        handle_before_schedule_eofed
      end

      # Trigger method for running on eof without messages
      def on_eofed
        handle_eofed
      rescue => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          seek_offset: seek_offset,
          type: "consumer.eofed.error"
        )
      end

      # Can be used to run code prior to scheduling of revoked execution
      #
      # @private
      def on_before_schedule_revoked
        handle_before_schedule_revoked
      end

      # Trigger method for running on partition revocation.
      #
      # @private
      def on_revoked
        handle_revoked
      rescue => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.revoked.error"
        )
      end

      # Pauses processing on a given offset or consecutive offset for the current topic partition
      #
      # After given partition is resumed, it will continue processing from the given offset
      # @param offset [Integer, Symbol] offset from which we want to restart the processing or
      #  `:consecutive` if we want to pause and continue without changing the consecutive offset
      #  (cursor position)
      # @param timeout [Integer, nil] how long in milliseconds do we want to pause or nil to use the
      #   default exponential pausing strategy defined for retries
      # @param manual_pause [Boolean] Flag to differentiate between user pause and system/strategy
      #   based pause. While they both pause in exactly the same way, the strategy application
      #   may need to differentiate between them.
      #
      # @note It is **critical** to understand how pause with `:consecutive` offset operates. While
      #   it provides benefit of not purging librdkafka buffer, in case of usage of filters, retries
      #   or other advanced options the consecutive offset may not be the one you want to pause on.
      #   Test it well to ensure, that this behaviour is expected by you.
      def pause(offset, timeout = nil, manual_pause = true)
        timeout ? coordinator.pause_tracker.pause(timeout) : coordinator.pause_tracker.pause

        offset = nil if offset == :consecutive

        client.pause(
          topic.name,
          partition,
          offset,
          coordinator.pause_tracker.current_timeout
        )

        # Indicate, that user took a manual action of pausing
        coordinator.manual_pause if manual_pause

        monitor.instrument(
          "consumer.consuming.pause",
          caller: self,
          manual: manual_pause,
          topic: topic.name,
          partition: partition,
          subscription_group: topic.subscription_group,
          offset: offset,
          timeout: coordinator.pause_tracker.current_timeout,
          attempt: attempt
        )
      end

      # Resumes processing of the current topic partition
      def resume
        return unless coordinator.pause_tracker.paused?

        # This is sufficient to expire a partition pause, as with it will be resumed by the listener
        # thread before the next poll.
        coordinator.pause_tracker.expire
      end

      # Seeks in the context of current topic and partition
      #
      # @param offset [Integer, Time, Symbol, String] one of:
      #   - offset where we want to seek
      #   - time of the offset where we want to seek
      #   - :earliest (or as a string) to move to earliest message
      #   - :latest (or as a string) to move to latest (high-watermark)
      #
      # @param manual_seek [Boolean] Flag to differentiate between user seek and system/strategy
      #   based seek. User seek operations should take precedence over system actions, hence we need
      #   to know who invoked it.
      # @param reset_offset [Boolean] should we reset offset when seeking backwards. It is false
      #   it prevents marking in the offset that was earlier than the highest marked offset
      #   for given consumer group. It is set to true by default to reprocess data once again and
      #   want to make sure that the marking starts from where we moved to.
      # @note Please note, that if you are seeking to a time offset, getting the offset is blocking
      def seek(offset, manual_seek = true, reset_offset: true)
        coordinator.manual_seek if manual_seek

        message = Karafka::Messages::Seek.new(
          topic.name,
          partition,
          offset
        )

        monitor.instrument(
          "consumer.consuming.seek",
          caller: self,
          topic: topic.name,
          partition: partition,
          message: message,
          manual_seek: manual_seek,
          reset_offset: reset_offset
        ) do
          client.seek(message)

          # We reset the seek offset only after the seek actually succeeded. Resetting it before the
          # seek would, on a raising seek (for example an unresolvable time-based offset), leave
          # seek_offset nil so the failure-driven retry would pause without seeking back and skip
          # the rest of the batch.
          self.seek_offset = nil if reset_offset
        end
      end

      # @return [Boolean] true if partition was revoked from the current consumer
      # @note There are two "levels" on which we can know that partition was revoked. First one is
      #   when we loose the assignment involuntarily and second is when coordinator gets this info
      #   after we poll with the rebalance callbacks. The first check allows us to get this notion
      #   even before we poll but it gets reset when polling happens, hence we also need to switch
      #   the coordinator state after the revocation (but prior to running more jobs)
      def revoked?
        return true if coordinator.revoked?
        return false unless client.assignment_lost?

        coordinator.revoke

        true
      end

      # @return [Boolean] are we retrying processing after an error. This can be used to provide a
      #   different flow after there is an error, for example for resources cleanup, small manual
      #   backoff or different instrumentation tracking.
      def retrying?
        attempt > 1
      end

      # @return [Integer] attempt of processing given batch. 1 if this is the first attempt or
      #   higher in case it is a retry
      def attempt
        coordinator.pause_tracker.attempt
      end

      # Pauses the processing from the last offset to retry on given message
      # @private
      def retry_after_pause
        pause(seek_offset, nil, false)

        # Instrumentation needs to run **after** `#pause` invocation because we rely on the states
        # set by `#pause`
        monitor.instrument(
          "consumer.consuming.retry",
          caller: self,
          topic: topic.name,
          partition: partition,
          offset: seek_offset,
          timeout: coordinator.pause_tracker.current_timeout,
          attempt: attempt
        )
      end

      private

      # Method that will be executed when a given topic partition reaches eof without any new
      # incoming messages alongside
      def eofed
      end

      # Method that will be executed when a given topic partition is revoked. You can use it for
      # some teardown procedures (closing file handler, etc).
      def revoked
      end
    end
  end
end

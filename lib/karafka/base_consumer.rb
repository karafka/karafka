# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    # Allow for consumer instance tagging for instrumentation
    include ::Karafka::Core::Taggable

    extend Forwardable

    def_delegators :@coordinator, :topic, :partition

    def_delegators :producer, :produce_async, :produce_sync, :produce_many_async,
                   :produce_many_sync

    # @return [String] id of the current consumer
    attr_reader :id
    # @return [Karafka::Routing::Topic] topic to which a given consumer is subscribed
    attr_accessor :messages
    # @return [Karafka::Connection::Client] kafka connection client
    attr_accessor :client
    # @return [Karafka::Processing::Coordinator] coordinator
    attr_accessor :coordinator
    # @return [Waterdrop::Producer] producer instance
    attr_accessor :producer

    # Creates new consumer and assigns it an id
    def initialize
      @id = SecureRandom.hex(6)
      @used = false
    end

    # Can be used to run preparation code prior to the job being enqueued
    #
    # @private
    # @note This should not be used by the end users as it is part of the lifecycle of things and
    #   not as a part of the public api. This should not perform any extensive operations as it is
    #   blocking and running in the listener thread.
    def on_before_schedule_consume
      @used = true
      handle_before_schedule_consume
    end

    # Can be used to run preparation code in the worker
    #
    # @private
    # @note This should not be used by the end users as it is part of the lifecycle of things and
    #   not as part of the public api. This can act as a hook when creating non-blocking
    #   consumers and doing other advanced stuff
    def on_before_consume
      messages.metadata.processed_at = Time.now
      messages.metadata.freeze

      # We run this after the full metadata setup, so we can use all the messages information
      # if needed
      handle_before_consume
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
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        seek_offset: coordinator.seek_offset,
        type: 'consumer.consume.error'
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
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        seek_offset: coordinator.seek_offset,
        type: 'consumer.after_consume.error'
      )

      retry_after_pause
    end

    # Can be used to run code prior to scheduling of idle execution
    #
    # @private
    def on_before_schedule_idle
      handle_before_schedule_idle
    end

    # Trigger method for running on idle runs without messages
    #
    # @private
    def on_idle
      handle_idle
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
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.revoked.error'
      )
    end

    # Can be used to run code prior to scheduling of revoked execution
    #
    # @private
    def on_before_schedule_shutdown
      handle_before_schedule_shutdown
    end

    # Trigger method for running on shutdown.
    #
    # @private
    def on_shutdown
      handle_shutdown
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.shutdown.error'
      )
    end

    private

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs to be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def consume
      raise NotImplementedError, 'Implement this in a subclass'
    end

    # Method that will be executed when a given topic partition is revoked. You can use it for
    # some teardown procedures (closing file handler, etc).
    def revoked; end

    # Method that will be executed when the process is shutting down. You can use it for
    # some teardown procedures (closing file handler, etc).
    def shutdown; end

    # @return [Boolean] was this consumer in active use. Active use means running `#consume` at
    #   least once. Consumer may have to run `#revoked` or `#shutdown` despite not running
    #   `#consume` previously in delayed job cases and other cases that potentially involve running
    #   the `Jobs::Idle` for house-keeping
    def used?
      @used
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

      client.pause(topic.name, partition, offset)

      # Indicate, that user took a manual action of pausing
      coordinator.manual_pause if manual_pause

      Karafka.monitor.instrument(
        'consumer.consuming.pause',
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
    # @param offset [Integer, Time] offset where we want to seek or time of the offset where we
    #   want to seek.
    # @param manual_seek [Boolean] Flag to differentiate between user seek and system/strategy
    #   based seek. User seek operations should take precedence over system actions, hence we need
    #   to know who invoked it.
    # @param reset_offset [Boolean] should we reset offset when seeking backwards. It is false by
    #   default to prevent marking in the offset that was earlier than the highest marked offset
    #   for given consumer group. It can be set to true if we want to reprocess data once again and
    #   want to make sure that the marking starts from where we moved to.
    # @note Please note, that if you are seeking to a time offset, getting the offset is blocking
    def seek(offset, manual_seek = true, reset_offset: false)
      coordinator.manual_seek if manual_seek
      coordinator.seek_offset = nil if reset_offset

      client.seek(
        Karafka::Messages::Seek.new(
          topic.name,
          partition,
          offset
        )
      )
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

    # @return [Integer] attempt of processing given batch. 1 if this is the first attempt or higher
    #  in case it is a retry
    def attempt
      coordinator.pause_tracker.attempt
    end

    # Pauses the processing from the last offset to retry on given message
    # @private
    def retry_after_pause
      pause(coordinator.seek_offset, nil, false)

      # Instrumentation needs to run **after** `#pause` invocation because we rely on the states
      # set by `#pause`
      Karafka.monitor.instrument(
        'consumer.consuming.retry',
        caller: self,
        topic: topic.name,
        partition: partition,
        offset: coordinator.seek_offset,
        timeout: coordinator.pause_tracker.current_timeout,
        attempt: attempt
      )
    end
  end
end

# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    # Allow for consumer instance tagging for instrumentation
    include ::Karafka::Core::Taggable

    extend Forwardable

    def_delegators :@coordinator, :topic, :partition

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
    end

    # Can be used to run preparation code prior to the job being enqueued
    #
    # @private
    # @note This should not be used by the end users as it is part of the lifecycle of things and
    #   not as a part of the public api. This should not perform any extensive operations as it is
    #   blocking and running in the listener thread.
    def on_before_enqueue
      handle_before_enqueue
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.before_enqueue.error'
      )
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
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.before_consume.error'
      )
    end

    # Executes the default consumer flow.
    #
    # @return [Boolean] true if there was no exception, otherwise false.
    #
    # @private
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
    # @note This should not be used by the end users as it is part of the lifecycle of things but
    #   not as part of the public api.
    def on_after_consume
      handle_after_consume
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.after_consume.error'
      )
    end

    # Trigger method for running on idle runs without messages
    #
    # @private
    def on_idle
      handle_idle
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        type: 'consumer.idle.error'
      )
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

    # Pauses processing on a given offset for the current topic partition
    #
    # After given partition is resumed, it will continue processing from the given offset
    # @param offset [Integer] offset from which we want to restart the processing
    # @param timeout [Integer, nil] how long in milliseconds do we want to pause or nil to use the
    #   default exponential pausing strategy defined for retries
    # @param manual_pause [Boolean] Flag to differentiate between user pause and system/strategy
    #   based pause. While they both pause in exactly the same way, the strategy application
    #   may need to differentiate between them.
    def pause(offset, timeout = nil, manual_pause = true)
      timeout ? coordinator.pause_tracker.pause(timeout) : coordinator.pause_tracker.pause

      client.pause(
        topic.name,
        partition,
        offset
      )

      # Indicate, that user took a manual action of pausing
      coordinator.manual_pause if manual_pause

      Karafka.monitor.instrument(
        'consumer.consuming.pause',
        caller: self,
        manual: manual_pause,
        topic: topic.name,
        partition: partition,
        offset: offset,
        timeout: coordinator.pause_tracker.current_timeout,
        attempt: coordinator.pause_tracker.attempt
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
    # @note Please note, that if you are seeking to a time offset, getting the offset is blocking
    def seek(offset, manual_seek = true)
      coordinator.manual_seek if manual_seek

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
      coordinator.pause_tracker.attempt > 1
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
        attempt: coordinator.pause_tracker.attempt
      )
    end
  end
end

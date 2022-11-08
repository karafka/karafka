# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    # @return [Karafka::Routing::Topic] topic to which a given consumer is subscribed
    attr_accessor :topic
    # @return [Karafka::Messages::Messages] current messages batch
    attr_accessor :messages
    # @return [Karafka::Connection::Client] kafka connection client
    attr_accessor :client
    # @return [Karafka::Processing::Coordinator] coordinator
    attr_accessor :coordinator
    # @return [Waterdrop::Producer] producer instance
    attr_accessor :producer

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
    # @note We keep the seek offset tracking, and use it to compensate for async offset flushing
    #   that may not yet kick in when error occurs. That way we pause always on the last processed
    #   message.
    def on_consume
      Karafka.monitor.instrument('consumer.consumed', caller: self) do
        consume
      end

      coordinator.consumption(self).success!
    rescue StandardError => e
      coordinator.consumption(self).failure!(e)

      Karafka.monitor.instrument(
        'error.occurred',
        error: e,
        caller: self,
        seek_offset: coordinator.seek_offset,
        type: 'consumer.consume.error'
      )
    ensure
      # We need to decrease number of jobs that this coordinator coordinates as it has finished
      coordinator.decrement
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

    # Trigger method for running on partition revocation.
    #
    # @private
    def on_revoked
      handle_revoked

      Karafka.monitor.instrument('consumer.revoked', caller: self) do
        revoked
      end
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
      Karafka.monitor.instrument('consumer.shutdown', caller: self) do
        shutdown
      end
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

    # Marks message as consumed in an async way.
    #
    # @param message [Messages::Message] last successfully processed message.
    # @return [Boolean] true if we were able to mark the offset, false otherwise. False indicates
    #   that we were not able and that we have lost the partition.
    #
    # @note We keep track of this offset in case we would mark as consumed and got error when
    #   processing another message. In case like this we do not pause on the message we've already
    #   processed but rather at the next one. This applies to both sync and async versions of this
    #   method.
    def mark_as_consumed(message)
      # Ignore earlier offsets than the one we alread committed
      return true if coordinator.seek_offset > message.offset

      unless client.mark_as_consumed(message)
        coordinator.revoke

        return false
      end

      coordinator.seek_offset = message.offset + 1

      true
    end

    # Marks message as consumed in a sync way.
    #
    # @param message [Messages::Message] last successfully processed message.
    # @return [Boolean] true if we were able to mark the offset, false otherwise. False indicates
    #   that we were not able and that we have lost the partition.
    def mark_as_consumed!(message)
      # Ignore earlier offsets than the one we alread committed
      return true if coordinator.seek_offset > message.offset

      unless client.mark_as_consumed!(message)
        coordinator.revoke

        return false
      end

      coordinator.seek_offset = message.offset + 1

      true
    end

    # Pauses processing on a given offset for the current topic partition
    #
    # After given partition is resumed, it will continue processing from the given offset
    # @param offset [Integer] offset from which we want to restart the processing
    # @param timeout [Integer, nil] how long in milliseconds do we want to pause or nil to use the
    #   default exponential pausing strategy defined for retries
    def pause(offset, timeout = nil)
      timeout ? coordinator.pause_tracker.pause(timeout) : coordinator.pause_tracker.pause

      client.pause(
        messages.metadata.topic,
        messages.metadata.partition,
        offset
      )
    end

    # Resumes processing of the current topic partition
    def resume
      # This is sufficient to expire a partition pause, as with it will be resumed by the listener
      # thread before the next poll.
      coordinator.pause_tracker.expire
    end

    # Seeks in the context of current topic and partition
    #
    # @param offset [Integer] offset where we want to seek
    def seek(offset)
      client.seek(
        Karafka::Messages::Seek.new(
          messages.metadata.topic,
          messages.metadata.partition,
          offset
        )
      )
    end

    # @return [Boolean] true if partition was revoked from the current consumer
    # @note We know that partition got revoked because when we try to mark message as consumed,
    #   unless if is successful, it will return false
    def revoked?
      coordinator.revoked?
    end
  end
end

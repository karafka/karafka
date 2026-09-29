# frozen_string_literal: true

module Karafka
  module Consumers
    # Share-group consumer (KIP-932 / Queues for Kafka).
    #
    # Share consumers acquire individual records under time-bounded broker leases and acknowledge
    # them per record (accept/release/reject) instead of committing partition offsets. This class
    # deliberately does not inherit the consumer-group offset/pause/seek/eof/revocation behavior.
    #
    # The default (and, for now, only) acknowledgement mode is explicit: inside `#consume` you call
    # {#mark_consumed}, {#mark_released} or {#mark_rejected} per message. Accumulated
    # acknowledgements are flushed to the broker after `#consume` returns successfully. Any record
    # left unacknowledged is redelivered by the broker after its acquisition lock expires.
    class ShareGroup < Base
      # @return [Symbol] group type
      def group_type
        :share
      end

      # Executes the default share consumer flow.
      #
      # @private
      #
      # @note The containment is intentionally broad (`Exception`): an error escaping here would
      #   bypass `#on_after_consume`, skipping the acknowledgement flush.
      def on_consume
        handle_consume
      rescue Exception => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.consume.error"
        )
      end

      # Runs the post-consumption flow (flushing acknowledgements).
      #
      # @private
      def on_after_consume
        handle_after_consume
      rescue Exception => e
        monitor.instrument(
          "error.occurred",
          error: e,
          caller: self,
          type: "consumer.after_consume.error"
        )
      end

      # Acknowledges a message as successfully consumed (ACCEPT) in an async way - the
      # acknowledgement is buffered and flushed to the broker on the next commit (which the
      # framework runs after `#consume`). The message will not be redelivered.
      #
      # `mark_consumed` is the canonical name, shared with the consumer-group consumer;
      # `mark_as_consumed` is kept as an alias for a consistent convention across both modes.
      #
      # @param message [Karafka::Messages::Message] message to mark as consumed
      def mark_consumed(message)
        client.mark_consumed(message)
      end

      alias_method :mark_as_consumed, :mark_consumed

      # Acknowledges a message as consumed (ACCEPT) and flushes acknowledgements synchronously, so
      # the accept is durable before returning.
      #
      # @param message [Karafka::Messages::Message] message to mark as consumed
      def mark_consumed!(message)
        client.mark_consumed(message)
        client.commit!
      end

      alias_method :mark_as_consumed!, :mark_consumed!

      # Releases a message back to the share group for redelivery (RELEASE) in an async way. The
      # broker will hand it to a consumer again (delivery count increments) until the
      # delivery-count limit is reached.
      #
      # @param message [Karafka::Messages::Message] message to release
      # @param delay [Integer, nil] optional delay in milliseconds before the message becomes
      #   available for redelivery. Delayed release is not implemented yet.
      # @raise [NotImplementedError] when a delay is provided
      def mark_released(message, delay: nil)
        raise_delayed_release_not_implemented(delay)

        client.mark_released(message)
      end

      # Releases a message (RELEASE) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to release
      # @param delay [Integer, nil] optional delay in milliseconds. Not implemented yet.
      # @raise [NotImplementedError] when a delay is provided
      def mark_released!(message, delay: nil)
        raise_delayed_release_not_implemented(delay)

        client.mark_released(message)
        client.commit!
      end

      # Rejects a message so it is not redelivered to this share group (REJECT) in an async way.
      # The broker archives it immediately.
      #
      # @param message [Karafka::Messages::Message] message to reject
      def mark_rejected(message)
        client.mark_rejected(message)
      end

      # Rejects a message (REJECT) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to reject
      def mark_rejected!(message)
        client.mark_rejected(message)
        client.commit!
      end

      # Extends the acquisition lock on a message being processed (RENEW), buying more time before
      # the broker considers it available for redelivery. Not implemented yet (expected to live in
      # Pro).
      #
      # @param _message [Karafka::Messages::Message] message whose lock we want to extend
      # @raise [NotImplementedError]
      def extend_lock!(_message)
        raise NotImplementedError, "Lock extension (`extend_lock!`) is not implemented yet"
      end

      private

      # Flushes the acknowledgements accumulated during `#consume` to the broker. Called by the
      # processing strategy after a successful consume.
      def commit_acknowledgements
        client.commit!
      end

      # @param delay [Integer, nil] delay in milliseconds
      # @raise [NotImplementedError] when a delay is provided (delayed release is not implemented)
      def raise_delayed_release_not_implemented(delay)
        return unless delay

        raise(
          NotImplementedError,
          "Delayed release (`mark_released(delay:)`) is not implemented yet"
        )
      end
    end
  end
end

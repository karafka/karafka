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
    # {#mark_accepted}, {#mark_released} or {#mark_rejected} per message. Accumulated
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

      # Acknowledges a message as successfully consumed (ACCEPT). It will not be redelivered.
      #
      # Named to match the consumer-group `#mark_as_consumed` so both consumer modes share the same
      # positive-acknowledgement convention.
      #
      # @param message [Karafka::Messages::Message] message to mark as consumed
      def mark_as_consumed(message)
        client.mark_as_consumed(message)
      end

      # Releases a message back to the share group for redelivery (RELEASE). The broker will hand
      # it to a consumer again (delivery count increments), until the delivery-count limit is
      # reached.
      #
      # @param message [Karafka::Messages::Message] message to release
      # @param delay [Integer, nil] optional delay in milliseconds before the message becomes
      #   available for redelivery. Delayed release is not implemented yet.
      # @raise [NotImplementedError] when a delay is provided
      def mark_released(message, delay: nil)
        if delay
          raise(
            NotImplementedError,
            "Delayed release (`mark_released(delay:)`) is not implemented yet"
          )
        end

        client.mark_released(message)
      end

      # Rejects a message so it is not redelivered to this share group (REJECT). The broker
      # archives it immediately.
      #
      # @param message [Karafka::Messages::Message] message to reject
      def mark_rejected(message)
        client.mark_rejected(message)
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
    end
  end
end

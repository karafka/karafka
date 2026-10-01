# frozen_string_literal: true

module Karafka
  module Consumers
    # Share-group consumer (KIP-932 / Queues for Kafka).
    #
    # Share consumers acquire individual records under time-bounded broker leases and acknowledge
    # them per record (accept/release/reject) instead of committing partition offsets. This class
    # deliberately does not inherit the consumer-group offset/pause/seek/eof/revocation behavior.
    #
    # The acknowledgement mode is explicit: inside `#consume` you call
    # {#mark_as_accepted}, {#mark_as_released} or {#mark_as_rejected} per message. Every record left
    # unacknowledged is settled once `#consume` finishes: after a success it gets the topic
    # `acknowledgements(unacknowledged:)` state (released for redelivery by default), after a
    # failure it is always released for redelivery. Acknowledgements are then flushed to the broker
    # asynchronously.
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

      # Acknowledges a message as accepted (ACCEPT / successfully processed) in an async way - the
      # acknowledgement is buffered and flushed to the broker on the next commit (which the
      # framework runs after `#consume`). The message will not be redelivered.
      #
      # @param message [Karafka::Messages::Message] message to accept
      def mark_as_accepted(message)
        client.mark_as_accepted(message)
      end

      # Acknowledges a message as accepted (ACCEPT) and flushes acknowledgements synchronously, so
      # the accept is durable before returning.
      #
      # @param message [Karafka::Messages::Message] message to accept
      def mark_as_accepted!(message)
        client.mark_as_accepted(message)
        client.commit!
      end

      # Releases a message back to the share group for redelivery (RELEASE) in an async way. The
      # broker will hand it to a consumer again (delivery count increments) until the
      # delivery-count limit is reached.
      #
      # @param message [Karafka::Messages::Message] message to release
      def mark_as_released(message)
        client.mark_as_released(message)
      end

      # Releases a message (RELEASE) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to release
      def mark_as_released!(message)
        client.mark_as_released(message)
        client.commit!
      end

      # Rejects a message so it is not redelivered to this share group (REJECT) in an async way.
      # The broker archives it immediately.
      #
      # @param message [Karafka::Messages::Message] message to reject
      def mark_as_rejected(message)
        client.mark_as_rejected(message)
      end

      # Rejects a message (REJECT) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to reject
      def mark_as_rejected!(message)
        client.mark_as_rejected(message)
        client.commit!
      end
    end
  end
end

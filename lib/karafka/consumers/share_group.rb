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
      # Client methods acknowledging a record with a given state
      ACKNOWLEDGEMENTS = {
        accept: :mark_as_accepted,
        release: :mark_as_released,
        reject: :mark_as_rejected
      }.freeze

      private_constant :ACKNOWLEDGEMENTS

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
      # acknowledgement is buffered and flushed to the broker after `#consume`. The message will
      # not be redelivered.
      #
      # @param message [Karafka::Messages::Message] message to accept
      # @return [Boolean] true if acknowledged, false if this message was already acknowledged
      #   (every record can be acknowledged only once)
      def mark_as_accepted(message)
        acknowledge(message, :accept)
      end

      # Acknowledges a message as accepted (ACCEPT) and flushes acknowledgements synchronously, so
      # the accept is durable before returning.
      #
      # @param message [Karafka::Messages::Message] message to accept
      # @return [Boolean] true if acknowledged and confirmed by the broker, false if this message
      #   was already acknowledged or the broker rejected the acknowledgement (for example because
      #   the acquisition lock of the record expired and it will be delivered again)
      def mark_as_accepted!(message)
        acknowledge(message, :accept, sync: true)
      end

      # Releases a message back to the share group for redelivery (RELEASE) in an async way. The
      # broker will hand it to a consumer again (delivery count increments) until the
      # delivery-count limit is reached.
      #
      # @param message [Karafka::Messages::Message] message to release
      # @return [Boolean] true if acknowledged, false if this message was already acknowledged
      def mark_as_released(message)
        acknowledge(message, :release)
      end

      # Releases a message (RELEASE) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to release
      # @return [Boolean] true if acknowledged and confirmed by the broker, false if this message
      #   was already acknowledged or the broker rejected the acknowledgement
      def mark_as_released!(message)
        acknowledge(message, :release, sync: true)
      end

      # Rejects a message so it is not redelivered to this share group (REJECT) in an async way.
      # The broker archives it immediately.
      #
      # @param message [Karafka::Messages::Message] message to reject
      # @return [Boolean] true if acknowledged, false if this message was already acknowledged
      def mark_as_rejected(message)
        acknowledge(message, :reject)
      end

      # Rejects a message (REJECT) and flushes acknowledgements synchronously.
      #
      # @param message [Karafka::Messages::Message] message to reject
      # @return [Boolean] true if acknowledged and confirmed by the broker, false if this message
      #   was already acknowledged or the broker rejected the acknowledgement
      def mark_as_rejected!(message)
        acknowledge(message, :reject, sync: true)
      end

      private

      # Acknowledges the message unless it was already acknowledged in the current batch
      #
      # @param message [Karafka::Messages::Message] message to acknowledge
      # @param state [Symbol] `:accept`, `:release` or `:reject`
      # @param sync [Boolean] should acknowledgements be flushed synchronously afterwards
      # @return [Boolean] true if acknowledged (and for sync, confirmed by the broker), false if
      #   this message was already acknowledged, the client is closed or the broker rejected it
      def acknowledge(message, state, sync: false)
        return false unless acknowledgements_tracker.acknowledge(message)
        return false unless client.public_send(ACKNOWLEDGEMENTS.fetch(state), message)
        return true unless sync

        confirmed?(client.commit!, message)
      end

      # @param result [Rdkafka::Consumer::TopicPartitionList, nil] outcome of a synchronous commit
      # @param message [Karafka::Messages::Message] acknowledged message
      # @return [Boolean] did the broker accept the acknowledgements of the message partition
      def confirmed?(result, message)
        return true unless result

        partition = result.to_h.fetch(message.topic, []).find do |details|
          details.partition == message.partition
        end

        partition.nil? || partition.err.to_i.zero?
      end

      # @return [Karafka::Processing::ShareGroups::AcknowledgementsTracker] tracker of this
      #   consumer acknowledgements within the current batch
      def acknowledgements_tracker
        @acknowledgements_tracker ||= Processing::ShareGroups::AcknowledgementsTracker.new
      end
    end
  end
end

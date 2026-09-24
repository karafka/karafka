# frozen_string_literal: true

module Karafka
  module Consumers
    # Share-group consumer (KIP-932 / Queues for Kafka).
    #
    # This is currently a shell: the share-group runtime is not implemented yet, so the per-record
    # acknowledgement API is defined only as stubs that raise. The startup guard
    # ({Karafka::App.verify_share_groups_inactive!}) prevents any share group from actually running
    # until the runtime lands, so these methods are never reached at runtime today. They exist so
    # the public consumer surface is stable and share consumers can already be defined and
    # introspected.
    #
    # It deliberately does not inherit the consumer-group offset/pause/seek/eof/revocation behavior
    # - share consumers acknowledge individual records (accept/release/reject) instead of
    # committing partition offsets.
    class ShareGroup < Base
      # Message used for the not-yet-implemented acknowledgement API
      NOT_IMPLEMENTED_MESSAGE = "Share group (KIP-932) runtime is not implemented yet"

      private_constant :NOT_IMPLEMENTED_MESSAGE

      # @return [Symbol] group type
      def group_type
        :share
      end

      # Acknowledges a message as successfully processed (ACCEPT).
      #
      # @param _message [Karafka::Messages::Message] message to accept
      # @raise [NotImplementedError] until the share-group runtime lands
      def mark_accepted(_message)
        raise NotImplementedError, NOT_IMPLEMENTED_MESSAGE
      end

      # Releases a message back to the share group for redelivery (RELEASE), optionally after a
      # delay.
      #
      # @param _message [Karafka::Messages::Message] message to release
      # @param delay [Integer, nil] optional delay in milliseconds before the message becomes
      #   available for redelivery
      # @raise [NotImplementedError] until the share-group runtime lands
      def mark_released(_message, delay: nil)
        raise NotImplementedError, NOT_IMPLEMENTED_MESSAGE
      end

      # Rejects a message so it is not redelivered to this share group (REJECT).
      #
      # @param _message [Karafka::Messages::Message] message to reject
      # @raise [NotImplementedError] until the share-group runtime lands
      def mark_rejected(_message)
        raise NotImplementedError, NOT_IMPLEMENTED_MESSAGE
      end

      # Extends the acquisition lock on a message being processed (RENEW), buying more time before
      # the broker considers it available for redelivery.
      #
      # @param _message [Karafka::Messages::Message] message whose lock we want to extend
      # @raise [NotImplementedError] until the share-group runtime lands
      def extend_lock!(_message)
        raise NotImplementedError, NOT_IMPLEMENTED_MESSAGE
      end
    end
  end
end

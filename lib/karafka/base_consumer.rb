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
    # @return [Karafka::TimeTrackers::Pause] current topic partition pause
    attr_accessor :pause
    # @return [Waterdrop::Producer] producer instance
    attr_accessor :producer

    # Executes the default consumer flow.
    #
    # @note We keep the seek offset tracking, and use it to compensate for async offset flushing
    #   that may not yet kick in when error occurs. That way we pause always on the last processed
    #   message.
    def on_consume
      Karafka.monitor.instrument('consumer.consume', caller: self) do
        consume
      end

      pause.reset

      # Mark as consumed only if manual offset management is not on
      return if topic.manual_offset_management

      # We use the non-blocking one here. If someone needs the blocking one, can implement it with
      # manual offset management
      mark_as_consumed(messages.last)
    rescue StandardError => e
      Karafka.monitor.instrument('consumer.consume.error', caller: self, error: e)
      client.pause(topic.name, messages.first.partition, @seek_offset || messages.first.offset)
      pause.pause
    end

    # Trigger method for running on shutdown.
    #
    # @private
    def on_revoked
      Karafka.monitor.instrument('consumer.revoked', caller: self) do
        revoked
      end
    rescue StandardError => e
      Karafka.monitor.instrument('consumer.revoked.error', caller: self, error: e)
    end

    # Trigger method for running on shutdown.
    #
    # @private
    def on_shutdown
      Karafka.monitor.instrument('consumer.shutdown', caller: self) do
        shutdown
      end
    rescue StandardError => e
      Karafka.monitor.instrument('consumer.shutdown.error', caller: self, error: e)
    end

    private

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
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
    def mark_as_consumed(message)
      client.mark_as_consumed(message)
      @seek_offset = message.offset + 1
    end

    # Marks message as consumed in a sync way.
    #
    # @param message [Messages::Message] last successfully processed message.
    def mark_as_consumed!(message)
      client.mark_as_consumed!(message)
      @seek_offset = message.offset + 1
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
  end
end

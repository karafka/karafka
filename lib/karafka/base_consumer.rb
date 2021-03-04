# frozen_string_literal: true

# Karafka module namespace
module Karafka
  # Base consumer from which all Karafka consumers should inherit
  class BaseConsumer
    # @return [Karafka::Routing::Topic] topic to which a given consumer is subscribed
    attr_accessor :topic
    # @return [Karafka::Params:ParamsBatch] current messages batch
    attr_accessor :messages
    # @return [Karafka::Connection::Client] kafka connection client
    attr_accessor :client

    attr_accessor :pause

    # Executes the default consumer flow.
    def on_consume
      Karafka.monitor.instrument('consumer.consume', caller: self) do
        consume
      end

      pause.reset

      # Mark as consumed only if manual offset management is not on
      return if topic.manual_offset_management

      mark_as_consumed(messages.last)
    rescue StandardError => e
      Karafka.monitor.instrument('consuming.error', caller: self, error: e)
      client.pause(topic.name, messages.first.partition, @seek_offset || messages.first.offset)
      pause.pause
    end

    def on_revoked
      Karafka.monitor.instrument('consumer.revoked', caller: self) do
        revoked
      end
    end

    def on_shutdown
      Karafka.monitor.instrument('consumer.shutdown', caller: self) do
        shutdown
      end
    end

    private

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def consume
      raise NotImplementedError, 'Implement this in a subclass'
    end

    def revoked
      #
    end

    def shutdown
      #
    end

    def mark_as_consumed(message)
      client.mark_as_consumed(message)
      @seek_offset = message.offset + 1
    end

    def mark_as_consumed!(message)
      client.mark_as_consumed!(message)
      @seek_offset = message.offset + 1
    end
  end
end

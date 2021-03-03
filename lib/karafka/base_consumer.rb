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
    def call
      Karafka.monitor.instrument('consuming.call', caller: self) do
        consume
      end

      pause.reset

      # TODO offset management (mark as consumed here)
    rescue StandardError => e
      Karafka.monitor.instrument('consuming.error', caller: self, error: e)
      client.pause(topic.name, messages.first.partition, @seek_offset || messages.first.offset)
      pause.pause
    end

    def revoked
      #
    end

    def shutdown
      #
    end

    private

    # Method that will perform business logic and on data received from Kafka (it will consume
    #   the data)
    # @note This method needs bo be implemented in a subclass. We stub it here as a failover if
    #   someone forgets about it or makes on with typo
    def consume
      raise NotImplementedError, 'Implement this in a subclass'
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

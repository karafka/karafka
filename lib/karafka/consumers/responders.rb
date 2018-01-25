# frozen_string_literal: true

module Karafka
  module Consumers
    # Feature that allows us to use responders flow in consumer
    module Responders
      # Responds with given data using given responder. This allows us to have a similar way of
      # defining flows like synchronous protocols
      # @param data Anything we want to pass to responder based on which we want to trigger further
      #   Kafka responding
      def respond_with(*data)
        Karafka.monitor.instrument(
          'consumers.responders.respond_with',
          caller: self,
          data: data
        ) do
          # @note we build a new instance of responder each time, as a long-running (persisted)
          #   consumers can respond multiple times during the lifecycle
          topic.responder.new(topic.parser).call(*data)
        end
      end
    end
  end
end

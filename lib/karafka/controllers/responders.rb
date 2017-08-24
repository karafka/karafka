# frozen_string_literal: true

module Karafka
  module Controllers
    # Feature that allows us to use responders flow in controller
    module Responders
      # @return [Karafka::BaseResponder] responder instance if defined
      # @return [nil] nil if no responder for this controller
      def responder
        @responder ||= topic.responder.new(topic.parser)
      end

      # Responds with given data using given responder. This allows us to have a similar way of
      # defining flows like synchronous protocols
      # @param data Anything we want to pass to responder based on which we want to trigger further
      #   Kafka responding
      def respond_with(*data)
        Karafka.monitor.notice(self.class, data: data)
        responder.call(*data)
      end
    end
  end
end

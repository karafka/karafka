# frozen_string_literal: true

module Karafka
  module Messages
    # Default message parser. The only thing it does, is calling the deserializer
    class Parser
      # @param message [::Karafka::Messages::Message]
      # @return [Object] deserialized payload
      def call(message)
        message.metadata.deserializer.call(message)
      end
    end
  end
end

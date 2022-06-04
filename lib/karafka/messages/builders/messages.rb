# frozen_string_literal: true

module Karafka
  module Messages
    module Builders
      # Builder for creating message batch instances.
      module Messages
        class << self
          # Creates messages batch with messages inside based on the incoming messages and the
          # topic from which it comes.
          #
          # @param kafka_messages [Array<Rdkafka::Consumer::Message>] raw fetched messages
          # @param topic [Karafka::Routing::Topic] topic for which we're received messages
          # @param received_at [Time] moment in time when the messages were received
          # @return [Karafka::Messages::Messages] messages batch object
          def call(kafka_messages, topic, received_at)
            messages_array = kafka_messages.map do |message|
              Karafka::Messages::Builders::Message.call(
                message,
                topic,
                received_at
              )
            end

            # We cannot freeze batch metadata because it contains fields that will be filled only
            # when the batch is picked for processing. It is mutable until we pick it up.
            # From the end user perspective, this is irrelevant, since he "receives" the whole
            # batch with metadata already frozen.
            metadata = BatchMetadata.call(
              kafka_messages,
              topic,
              received_at
            )

            Karafka::Messages::Messages.new(
              messages_array,
              metadata
            ).freeze
          end
        end
      end
    end
  end
end

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
          # @param messages [Array<Karafka::Messages::Message>] karafka messages array
          # @param topic [Karafka::Routing::Topic] topic for which we're received messages
          # @param partition [Integer] partition of those messages
          # @param received_at [Time] moment in time when the messages were received
          # @return [Karafka::Messages::Messages] messages batch object
          def call(messages, topic, partition, received_at)
            # We cannot freeze the batch metadata because it is altered with the processed_at time
            # prior to the consumption. It is being frozen there
            metadata = BatchMetadata.call(
              messages,
              topic,
              partition,
              received_at
            )

            Karafka::Messages::Messages.new(
              messages,
              metadata
            ).freeze
          end
        end
      end
    end
  end
end

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
          # @param received_at [Time] moment in time when the messages were received
          # @return [Karafka::Messages::Messages] messages batch object
          def call(messages, topic, received_at)
            # We cannot freeze batch metadata because it contains fields that will be filled only
            # when the batch is picked for processing. It is mutable until we pick it up.
            # From the end user perspective, this is irrelevant, since he "receives" the whole
            # batch with metadata already frozen.
            metadata = BatchMetadata.call(
              messages,
              topic,
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

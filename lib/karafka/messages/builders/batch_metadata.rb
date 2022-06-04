# frozen_string_literal: true

module Karafka
  module Messages
    module Builders
      # Builder for creating batch metadata object based on the batch informations.
      module BatchMetadata
        class << self
          # Creates metadata based on the kafka batch data.
          #
          # @param messages [Array<Karafka::Messages::Message>] messages array
          # @param topic [Karafka::Routing::Topic] topic for which we've fetched the batch
          # @param scheduled_at [Time] moment when the batch was scheduled for processing
          # @return [Karafka::Messages::BatchMetadata] batch metadata object
          #
          # @note We do not set `processed_at` as this needs to be assigned when the batch is
          #   picked up for processing.
          def call(messages, topic, scheduled_at)
            Karafka::Messages::BatchMetadata.new(
              size: messages.count,
              first_offset: messages.first.offset,
              last_offset: messages.last.offset,
              deserializer: topic.deserializer,
              partition: messages.first.partition,
              topic: topic.name,
              # We go with the assumption that the creation of the whole batch is the last message
              # creation time
              created_at: messages.last.timestamp,
              # When this batch was built and scheduled for execution
              scheduled_at: scheduled_at,
              # We build the batch metadata when we pick up the job in the worker, thus we can use
              # current time here
              processed_at: Time.now
            )
          end
        end
      end
    end
  end
end

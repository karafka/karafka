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
          # @param partition [Integer] partition of this metadata
          # @param scheduled_at [Time] moment when the batch was scheduled for processing
          # @return [Karafka::Messages::BatchMetadata] batch metadata object
          #
          # @note We do not set `processed_at` as this needs to be assigned when the batch is
          #   picked up for processing.
          def call(messages, topic, partition, scheduled_at)
            Karafka::Messages::BatchMetadata.new(
              size: messages.size,
              first_offset: messages.first&.offset || -1001,
              last_offset: messages.last&.offset || -1001,
              deserializers: topic.deserializers,
              partition: partition,
              topic: topic.name,
              # We go with the assumption that the creation of the whole batch is the last message
              # creation time
              created_at: local_created_at(messages.last),
              # When this batch was built and scheduled for execution
              scheduled_at: scheduled_at,
              # This needs to be set to a correct value prior to processing starting
              processed_at: nil
            )
          end

          private

          # Code that aligns the batch creation at into our local time. If time of current machine
          # and the Kafka cluster drift, this helps not to allow this to leak into the framework.
          #
          # @param last_message [::Karafka::Messages::Message, nil] last message from the batch or
          #   nil if no message
          # @return [Time] batch creation time. Now if no messages (workless flow) or the last
          #   message time as long as the message is not from the future
          # @note Message can be from the future in case consumer machine and Kafka cluster drift
          #   apart and the machine is behind the cluster.
          def local_created_at(last_message)
            now = ::Time.now

            return now unless last_message

            timestamp = last_message.timestamp
            timestamp > now ? now : timestamp
          end
        end
      end
    end
  end
end

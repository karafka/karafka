# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # All code needed for messages piping in Karafka
      module Piping
        # Consumer piping functionality
        #
        # It provides way to pipe data in a consistent way with extra traceability headers similar
        # to those in the enhanced DLQ.
        module Consumer
          # Empty hash to save on memory allocations
          EMPTY_HASH = {}.freeze

          private_constant :EMPTY_HASH

          # Pipes given message to the provided topic with expected details. Useful for
          # pass-through operations where deserialization is not needed. Upon usage it will include
          # all the original headers + meta headers about the source of message.
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param message [Karafka::Messages::Message] original message to pipe
          #
          # @note It will NOT deserialize the payload so it is fast
          #
          # @note We assume that there can be different number of partitions in the target topic,
          #   this is why we use `key` based on the original topic key and not the partition id.
          #   This will not utilize partitions beyond the number of partitions of original topic,
          #   but will accommodate for topics with less partitions.
          def pipe_async(topic:, message:)
            produce_async(
              build_pipe_message(topic: topic, message: message)
            )
          end

          # Sync version of pipe for one message
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param message [Karafka::Messages::Message] original message to pipe
          # @see [#pipe_async]
          def pipe_sync(topic:, message:)
            produce_sync(
              build_pipe_message(topic: topic, message: message)
            )
          end

          # Async multi-message pipe
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param messages [Array<Karafka::Messages::Message>] original messages to pipe
          #
          # @note If transactional producer in use and dispatch is not wrapped with a transaction,
          #   it will automatically wrap the dispatch with a transaction
          def pipe_many_async(topic:, messages:)
            messages = messages.map do |message|
              build_pipe_message(topic: topic, message: message)
            end

            produce_many_async(messages)
          end

          # Sync multi-message pipe
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param messages [Array<Karafka::Messages::Message>] original messages to pipe
          #
          # @note If transactional producer in use and dispatch is not wrapped with a transaction,
          #   it will automatically wrap the dispatch with a transaction
          def pipe_many_sync(topic:, messages:)
            messages = messages.map do |message|
              build_pipe_message(topic: topic, message: message)
            end

            produce_many_sync(messages)
          end

          private

          # @param topic [String, Symbol] where we want to send the message
          # @param message [Karafka::Messages::Message] original message to pipe
          # @return [Hash] hash with message to pipe.
          #
          # @note If you need to alter this, please define the `#enhance_pipe_message` method
          def build_pipe_message(topic:, message:)
            pipe_message = {
              topic: topic,
              payload: message.raw_payload,
              headers: message.raw_headers.merge(
                'original_topic' => message.topic,
                'original_partition' => message.partition.to_s,
                'original_offset' => message.offset.to_s,
                'original_consumer_group' => self.topic.consumer_group.id
              )
            }

            # Use a key only if key was provided
            if message.raw_key
              pipe_message[:key] = message.raw_key
            # Otherwise pipe creating a key that will assign it based on the original partition
            # number
            else
              pipe_message[:key] = message.partition.to_s
            end

            # Optional method user can define in consumer to enhance the dlq message hash with
            # some extra details if needed or to replace payload, etc
            if respond_to?(:enhance_pipe_message, true)
              enhance_pipe_message(
                pipe_message,
                message
              )
            end

            pipe_message
          end
        end
      end
    end
  end
end

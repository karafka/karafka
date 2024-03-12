# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
          #   this is why we use `key` based on the original topic partition number and not the
          #   partition id itself. This will not utilize partitions beyond the number of partitions
          #   of original topic, but will accommodate for topics with less partitions.
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
            original_partition = message.partition.to_s

            pipe_message = {
              topic: topic,
              key: original_partition,
              payload: message.raw_payload,
              headers: message.headers.merge(
                'original_topic' => message.topic,
                'original_partition' => original_partition,
                'original_offset' => message.offset.to_s,
                'original_consumer_group' => self.topic.consumer_group.id
              )
            }

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

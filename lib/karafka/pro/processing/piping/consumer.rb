# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
          # all the source headers + meta headers about the source of message.
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param message [Karafka::Messages::Message] source message to pipe
          #
          # @note It will NOT deserialize the payload so it is fast
          #
          # @note We assume that there can be different number of partitions in the target topic,
          #   this is why we use `key` based on the source topic key and not the partition id.
          #   This will not utilize partitions beyond the number of partitions of source topic,
          #   but will accommodate for topics with less partitions.
          def pipe_async(topic:, message:)
            produce_async(
              build_pipe_message(topic: topic, message: message)
            )
          end

          # Sync version of pipe for one message
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param message [Karafka::Messages::Message] source message to pipe
          # @see [#pipe_async]
          def pipe_sync(topic:, message:)
            produce_sync(
              build_pipe_message(topic: topic, message: message)
            )
          end

          # Async multi-message pipe
          #
          # @param topic [String, Symbol] where we want to send the message
          # @param messages [Array<Karafka::Messages::Message>] source messages to pipe
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
          # @param messages [Array<Karafka::Messages::Message>] source messages to pipe
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
          # @param message [Karafka::Messages::Message] source message to pipe
          # @return [Hash] hash with message to pipe.
          #
          # @note If you need to alter this, please define the `#enhance_pipe_message` method
          def build_pipe_message(topic:, message:)
            pipe_message = {
              topic: topic,
              payload: message.raw_payload,
              headers: message.raw_headers.merge(
                "source_topic" => message.topic,
                "source_partition" => message.partition.to_s,
                "source_offset" => message.offset.to_s,
                "source_consumer_group" => self.topic.consumer_group.id
              )
            }

            # Use a key only if key was provided
            pipe_message[:key] = if message.raw_key
              message.raw_key
            # Otherwise pipe creating a key that will assign it based on the source partition
            # number
            else
              message.partition.to_s
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

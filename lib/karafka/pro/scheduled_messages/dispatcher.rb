# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module ScheduledMessages
      # Dispatcher responsible for dispatching the messages to appropriate target topics and for
      # dispatching other messages. All messages (aside from the once users dispatch with the
      # envelope) are sent via this dispatcher.
      #
      # Messages are buffered and dispatched in batches to improve dispatch performance.
      class Dispatcher
        # @return [Array<Hash>] buffer with message hashes for dispatch
        attr_reader :buffer

        # @param topic [String] consumed topic name
        # @param partition [Integer] consumed partition
        def initialize(topic, partition)
          @topic = topic
          @partition = partition
          @buffer = []
          # Source (daily buffer) key aligned 1:1 with each `@buffer` entry, so `#flush` can report
          # which keys were confirmed delivered per chunk and the consumer can evict them
          # incrementally instead of only after the whole flush succeeds
          @keys = []
          @serializer = Serializer.new
        end

        # Prepares the scheduled message to the dispatch to the target topic. Extracts all the
        # "schedule_" details and prepares it, so the dispatched message goes with the expected
        # attributes to the desired location. Alongside of that it actually builds 2
        # (1 if logs off) messages: tombstone event matching the schedule so it is no longer valid
        # and the log message that has the same data as the dispatched message. Helpful when
        # debugging.
        #
        # @param message [Karafka::Messages::Message] message from the schedules topic.
        #
        # @note This method adds the message to the buffer, does **not** dispatch it.
        # @note It also produces needed tombstone event as well as an audit log message
        def <<(message)
          target_headers = message.raw_headers.merge(
            "schedule_source_topic" => @topic,
            "schedule_source_partition" => @partition.to_s,
            "schedule_source_offset" => message.offset.to_s,
            "schedule_source_key" => message.key
          ).compact

          target = {
            payload: message.raw_payload,
            headers: target_headers
          }

          extract(target, message.headers, :topic)
          extract(target, message.headers, :partition)
          extract(target, message.headers, :key)
          extract(target, message.headers, :partition_key)

          @buffer << target
          @keys << message.key

          # Tombstone message so this schedule is no longer in use and gets removed from Kafka by
          # Kafka itself during compacting. It will not cancel it because already dispatched but
          # will cause it not to be sent again and will be marked as dispatched.
          @buffer << Proxy.tombstone(message: message)
          @keys << message.key
        end

        # Builds and dispatches the state report message with schedules details
        #
        # @param tracker [Tracker]
        #
        # @note This is dispatched async because it's just a statistical metric.
        def state(tracker)
          config.producer.produce_async(
            topic: "#{@topic}#{config.states_postfix}",
            payload: @serializer.state(tracker),
            # We use the state as a key, so we always have one state transition data available
            key: "#{tracker.state}_state",
            partition: @partition,
            headers: { "zlib" => "true" }
          )
        end

        # Sends all messages to Kafka in a sync way.
        # We use sync with batches to prevent overloading.
        # When transactional producer in use, this will be wrapped in a transaction automatically.
        #
        # @yieldparam [Array<String>] keys of the chunk that was just confirmed delivered. Yielded
        #   after each chunk's sync produce returns, so the caller can evict those keys from the
        #   daily buffer incrementally. If a later chunk raises, the chunks already produced have
        #   still been reported, so a non-transactional producer will not re-dispatch them.
        # @raise [ArgumentError] when called without a block, since a caller that cannot observe
        #   per-chunk confirmations cannot evict incrementally and would reintroduce the
        #   whole-flush-or-nothing duplicate-dispatch window this method exists to close
        def flush
          raise ArgumentError, "#flush requires a block to report per-chunk confirmations" unless block_given?

          until @buffer.empty?
            batch_size = config.flush_batch_size

            # A message's target and its tombstone are always buffered as an adjacent pair (see
            # `#<<`). Rounding the chunk size up to even guarantees a chunk boundary can never
            # fall between them - with an odd (or 1) `flush_batch_size`, a chunk could otherwise
            # confirm and yield a key whose target was produced but whose tombstone was not, and a
            # later chunk failing would then leave that schedule non-tombstoned in Kafka, to be
            # re-dispatched after a restart/reload.
            batch_size += 1 if batch_size.odd?

            messages = @buffer.shift(batch_size)
            keys = @keys.shift(batch_size)

            config.producer.produce_many_sync(messages)

            yield(keys)
          end
        ensure
          # Whether flush finished normally (buffer already empty here, so this is a no-op) or
          # raised partway through, drop anything left. Those messages are still in the daily
          # buffer (their keys were never yielded, so never evicted) and will be re-buffered on
          # the next tick, so stale leftovers here must not be dispatched a second time.
          @buffer.clear
          @keys.clear
        end

        private

        # @return [Karafka::Core::Configurable::Node] scheduled messages config node
        def config
          @config ||= Karafka::App.config.scheduled_messages
        end

        # Extracts and copies the future attribute to a proper place in the target message.
        #
        # @param target [Hash]
        # @param headers [Hash]
        # @param attribute [Symbol]
        def extract(target, headers, attribute)
          schedule_attribute = "schedule_target_#{attribute}"

          return unless headers.key?(schedule_attribute)

          target[attribute] = headers[schedule_attribute]
        end
      end
    end
  end
end

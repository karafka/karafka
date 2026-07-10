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
    module Instrumentation
      module PausedLags
        # Periodically refreshes watermarks and lags of long-paused partitions using the running
        # consumer connection. Runs on the listener threads via the `client.events_poll` event,
        # so all the broker queries happen on the thread that owns the client connection and no
        # dedicated instances are created.
        #
        # A partition is considered long-paused when it was paused during two consecutive
        # refresh ticks, so no timestamps tracking is needed. Errors are ignored (values stay
        # stale until the next successful refresh) with an exponentially backed off retry.
        class Refresher
          include Karafka::Core::Helpers::Time
          include Helpers::ConfigImporter.new(
            interval: %i[internal statistics paused_refresh interval]
          )

          # Max multiplier of the interval used for the errors backoff
          MAX_BACKOFF_MULTIPLIER = 8

          private_constant :MAX_BACKOFF_MULTIPLIER

          def initialize
            @mutex = Mutex.new
            @states = {}
          end

          # Refreshes long-paused partitions data if the refresh is due for a given
          # subscription group
          #
          # @param event [Karafka::Core::Monitoring::Event] event with the client
          def on_client_events_poll(event)
            client = event[:caller]
            state = state_for(event[:subscription_group].id)

            return if monotonic_now < state[:next_at]

            paused_now = client.paused
            long_paused = intersect(state[:previous_paused], paused_now)

            state[:previous_paused] = paused_now
            state[:next_at] = monotonic_now + interval
            state[:client_name] = client.name

            return if long_paused.empty?

            Registry.instance.update(client.name, refresh(client, long_paused))

            state[:failures] = 0
          rescue
            return unless state

            # Refreshing is a best-effort operation: values stay stale until the next successful
            # run, so we only back off to not hammer an unhealthy cluster
            state[:failures] += 1
            backoff = interval * [2**state[:failures], MAX_BACKOFF_MULTIPLIER].min
            state[:next_at] = monotonic_now + backoff
          end

          # Expires all the refreshed data and pause tracking of a client on a rebalance, as
          # its paused partitions may no longer belong to it
          #
          # @param event [Karafka::Core::Monitoring::Event] revocation event
          def on_rebalance_partitions_revoked(event)
            state = state_for(event[:subscription_group].id)
            state[:previous_paused] = {}

            client_name = state[:client_name]

            Registry.instance.evict(client_name) if client_name
          end

          private

          # @param subscription_group_id [String]
          # @return [Hash] mutable state of a given subscription group. Aside from creation,
          #   accessed only from the subscription group own listener thread.
          def state_for(subscription_group_id)
            @mutex.synchronize do
              @states[subscription_group_id] ||= {
                next_at: 0,
                previous_paused: {},
                failures: 0,
                client_name: nil
              }
            end
          end

          # @param previous [Hash{String => Array<Integer>}] paused during the previous tick
          # @param current [Hash{String => Array<Integer>}] paused now
          # @return [Hash{String => Array<Integer>}] partitions paused during both ticks
          def intersect(previous, current)
            result = {}

            current.each do |topic, partitions|
              both = partitions & (previous[topic] || [])
              result[topic] = both unless both.empty?
            end

            result
          end

          # Fetches committed offsets (one batched query) and watermarks (per partition) for
          # the long-paused partitions via the client own connection
          #
          # @param client [Karafka::Connection::Client]
          # @param long_paused [Hash{String => Array<Integer>}]
          # @return [Hash{String => Hash{Integer => Hash}}] refreshed data
          def refresh(client, long_paused)
            tpl = Rdkafka::Consumer::TopicPartitionList.new
            long_paused.each { |topic, partitions| tpl.add_topic(topic, partitions) }

            data = {}

            client.committed(tpl).to_h.each do |topic, partitions|
              partitions.each do |partition|
                low, high = client.query_watermark_offsets(topic, partition.partition)

                (data[topic] ||= {})[partition.partition] = {
                  lo_offset: low,
                  hi_offset: high,
                  committed_offset: partition.offset || -1
                }
              end
            end

            data
          end
        end
      end
    end
  end
end

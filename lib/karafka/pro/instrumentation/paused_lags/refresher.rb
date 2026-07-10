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
        # refresh ticks, so no per-partition pause timestamps tracking is needed. Errors never
        # propagate (values stay stale until the next successful refresh) but are instrumented
        # and retried with an exponentially backed off delay.
        #
        # A single tick refreshes at most `MAX_PARTITIONS_PER_TICK` partitions, cycling through
        # the remaining ones round-robin on the following ticks, so a refresh can never stall
        # the listener thread for an extended time regardless of how many partitions are paused.
        class Refresher
          include Karafka::Core::Helpers::Time
          include Helpers::ConfigImporter.new(
            monitor: %i[monitor],
            interval: %i[internal statistics paused_refresh interval]
          )

          # Max exponent of the interval based errors backoff (2^3 => up to 8x the interval).
          # The counter itself is capped at this value so it cannot grow unbounded
          MAX_BACKOFF_EXPONENT = 3

          # Max number of partitions queried during a single tick. The watermark queries are
          # sequential blocking broker roundtrips on the listener thread, so we bound the per
          # tick work and round-robin the remainder across the following ticks
          MAX_PARTITIONS_PER_TICK = 20

          private_constant :MAX_BACKOFF_EXPONENT, :MAX_PARTITIONS_PER_TICK

          def initialize
            @mutex = Mutex.new
            @states = {}
          end

          # Refreshes long-paused partitions data if the refresh is due for a given
          # subscription group
          #
          # @param event [Karafka::Core::Monitoring::Event] event with the client
          def on_client_events_poll(event)
            # Never run during shutdown or quieting: blocking broker queries at that time would
            # eat into the shutdown time budget for no benefit
            return if Karafka::App.done?

            client = event[:caller]
            state = state_for(event[:subscription_group].id)

            return if monotonic_now < state[:next_at]

            paused_now = client.paused
            long_paused = intersect(state[:previous_paused], paused_now)

            state[:previous_paused] = paused_now
            state[:next_at] = monotonic_now + interval
            state[:client_name] = client.name

            # Drop data of partitions that are no longer paused so stale values never overlay
            # live librdkafka statistics of partitions that resumed and are actively consumed
            Registry.instance.retain(client.name, paused_now)

            if long_paused.empty?
              # A completed tick with nothing to refresh means previous errors are not relevant
              # anymore and the next error should start the backoff ladder from the beginning
              state[:failures] = 0

              return
            end

            Registry.instance.update(
              client.name,
              refresh(client, batch_for(state, long_paused))
            )

            state[:failures] = 0
          rescue => e
            return unless state

            # Refreshing is a best-effort operation: values stay stale until the next successful
            # run, so we only back off to not hammer an unhealthy cluster. The counter is capped
            # so it cannot grow unbounded across a long process lifetime
            state[:failures] = [state[:failures] + 1, MAX_BACKOFF_EXPONENT].min
            state[:next_at] = monotonic_now + (interval * (2**state[:failures]))

            # We swallow and back off but errors are still instrumented, so persistent failures
            # (missing ACLs, removed topics, etc) remain observable
            monitor.instrument(
              "error.occurred",
              caller: self,
              error: e,
              type: "paused_lags.refresher.error"
            )
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
                cursor: 0,
                client_name: nil
              }
            end
          end

          # Selects at most `MAX_PARTITIONS_PER_TICK` partitions to refresh during this tick,
          # cycling through all the long-paused partitions round-robin across consecutive ticks
          #
          # @param state [Hash] subscription group state (cursor tracking)
          # @param long_paused [Hash{String => Array<Integer>}] all long-paused partitions
          # @return [Hash{String => Array<Integer>}] partitions to refresh in this tick
          def batch_for(state, long_paused)
            pairs = long_paused.flat_map do |topic, partitions|
              partitions.map { |partition| [topic, partition] }
            end

            if pairs.size > MAX_PARTITIONS_PER_TICK
              start = state[:cursor] % pairs.size
              state[:cursor] = (start + MAX_PARTITIONS_PER_TICK) % pairs.size
              pairs = pairs.rotate(start).first(MAX_PARTITIONS_PER_TICK)
            end

            pairs.group_by(&:first).transform_values { |group| group.map(&:last) }
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

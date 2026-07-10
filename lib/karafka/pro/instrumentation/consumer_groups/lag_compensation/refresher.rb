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
      # Instrumentation components for consumer groups based operation
      module ConsumerGroups
        # Active refreshing of watermarks and lags for long-paused partitions. librdkafka only
        # updates those values from fetch responses, so partitions paused for a long time
        # report frozen statistics. The refresher periodically fetches fresh values and the
        # decorator overlays them onto the emitted statistics.
        module LagCompensation
          # Refreshes offsets and lags data of partitions that stayed paused for at least the
          # configured pause age, at most once per interval.
          #
          # Runs on the listener threads via the `client.events_poll` event, so the fetching
          # happens on the thread that owns the client connection within its group identity.
          # Pause state is tracked via the `client.pause` and `client.resume` instrumentation
          # events, which fire on the same thread.
          #
          # On resume or revocation the partition data is dropped immediately, so stale values
          # never overlay live statistics and revoked partitions are never queried again.
          # Errors never propagate and are only instrumented: the next attempt happens on the
          # next interval anyway.
          class Refresher
            include Karafka::Core::Helpers::Time
            include Helpers::ConfigImporter.new(
              monitor: %i[monitor],
              interval: %i[internal statistics consumer_groups lag_compensation interval],
              pause_age: %i[internal statistics consumer_groups lag_compensation pause_age]
            )

            def initialize
              @fetcher = Fetcher.new
              @mutex = Mutex.new
              @states = Hash.new do |states, subscription_group_id|
                states[subscription_group_id] = {
                  # Gates the refreshing to run at most once per interval
                  runner: Helpers::IntervalRunner.new(interval: interval) do |client, state|
                    refresh_tick(client, state)
                  end,
                  paused: Hash.new { |paused, topic| paused[topic] = {} },
                  client_name: nil
                }
              end
            end

            # Tracks when a given partition got paused
            #
            # @param event [Karafka::Core::Monitoring::Event] pause event
            def on_client_pause(event)
              state = state_for(event[:subscription_group].id)

              state[:paused][event[:topic]][event[:partition]] = monotonic_now
              state[:client_name] = event[:caller].name
            end

            # Stops tracking a resumed partition and drops its refreshed data immediately, so
            # stale values never overlay the live statistics of an actively consumed partition
            #
            # @param event [Karafka::Core::Monitoring::Event] resume event
            def on_client_resume(event)
              state = state_for(event[:subscription_group].id)
              # Fetch with a fallback not to auto-build tracking of an untracked topic
              partitions = state[:paused].fetch(event[:topic], nil)

              return unless partitions
              return unless partitions.delete(event[:partition])

              state[:paused].delete(event[:topic]) if partitions.empty?

              Registry.instance.retain(
                event[:caller].name,
                state[:paused].transform_values(&:keys)
              )
            end

            # Once per interval refreshes the data of all the partitions that stayed paused
            # for at least the configured pause age
            #
            # @param event [Karafka::Core::Monitoring::Event] event with the client
            def on_client_events_poll(event)
              # Never run during shutdown or quieting: blocking broker queries at that time
              # would eat into the shutdown time budget for no benefit
              return if Karafka::App.done?

              state = state_for(event[:subscription_group].id)

              state[:runner].call(event[:caller], state)
            rescue => e
              # Refreshing is a best-effort operation: values stay stale until the next
              # successful run on one of the following intervals. Errors are still
              # instrumented, so persistent failures (missing ACLs, removed topics, etc)
              # remain observable
              monitor.instrument(
                "error.occurred",
                caller: self,
                error: e,
                type: "lag_compensation.refresher.error"
              )
            end

            # Expires all the refreshed data and pause tracking of a client on a rebalance. Its
            # paused partitions may no longer belong to it and tracking will refill only via
            # real pause events of partitions this client still owns.
            #
            # @param event [Karafka::Core::Monitoring::Event] revocation event
            def on_rebalance_partitions_revoked(event)
              state = state_for(event[:subscription_group].id)
              # Clear (instead of a reassignment) preserves the auto-building behavior
              state[:paused].clear

              client_name = state[:client_name]

              Registry.instance.evict(client_name) if client_name
            end

            private

            # @param subscription_group_id [String]
            # @return [Hash] mutable state of a given subscription group. The mutex guards the
            #   cross-thread auto-building; aside from creation, the state is accessed only
            #   from the subscription group own listener thread.
            def state_for(subscription_group_id)
              @mutex.synchronize do
                @states[subscription_group_id]
              end
            end

            # Refreshes and stores the data of all the long-paused partitions (if any)
            #
            # @param client [Karafka::Connection::Client]
            # @param state [Hash] subscription group state
            def refresh_tick(client, state)
              state[:client_name] = client.name

              long_paused = long_paused_for(state)

              return if long_paused.empty?

              Registry.instance.update(client.name, @fetcher.call(client, long_paused))
            end

            # @param state [Hash] subscription group state with pause timestamps
            # @return [Hash{String => Array<Integer>}] partitions that stayed paused for at
            #   least the configured pause age
            def long_paused_for(state)
              threshold = monotonic_now - pause_age
              result = {}

              state[:paused].each do |topic, partitions|
                long_paused = partitions.select { |_, at| at <= threshold }.keys
                result[topic] = long_paused unless long_paused.empty?
              end

              result
            end
          end
        end
      end
    end
  end
end

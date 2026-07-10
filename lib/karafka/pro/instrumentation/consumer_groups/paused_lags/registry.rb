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
        # report frozen statistics. The refresher periodically fetches fresh values via the
        # running consumer connection and the decorator overlays them onto the emitted
        # statistics.
        module PausedLags
          # Thread-safe storage for actively refreshed watermarks and lags of long-paused
          # partitions. Written by the refresher on listener threads, read by the statistics
          # decorator on the librdkafka callbacks thread.
          #
          # No age based expiry is needed: entries are actively removed on resume and on
          # rebalances and replaced on refresh, so their lifecycle mirrors the pause tracking.
          class Registry
            include Singleton

            # Used to compare against without allocations when a topic has no paused partitions
            EMPTY_ARRAY = [].freeze

            private_constant :EMPTY_ARRAY

            def initialize
              @mutex = Mutex.new
              @clients = {}
            end

            # Stores refreshed data for a given client, replacing any previously stored one.
            # Each refresh covers all the long-paused partitions of a client, so a plain
            # replacement is always complete. Data of partitions that resumed is removed via
            # `#retain`.
            #
            # @param client_name [String] rdkafka client name (matches statistics `name` field)
            # @param data [Hash{String => Hash{Integer => Hash}}] topics with partitions with
            #   `:hi_offset`, `:ls_offset` and `:committed_offset` values
            def update(client_name, data)
              @mutex.synchronize do
                @clients[client_name] = data
              end
            end

            # Removes stored data of all the partitions that are not in the given paused set,
            # so values of partitions that resumed never overlay their live statistics
            #
            # @param client_name [String] rdkafka client name
            # @param paused [Hash{String => Array<Integer>}] currently paused topics with
            #   partitions
            def retain(client_name, paused)
              @mutex.synchronize do
                data = @clients[client_name]

                return unless data

                filtered = {}

                data.each do |topic, partitions|
                  paused_partitions = paused[topic] || EMPTY_ARRAY
                  kept = partitions.slice(*paused_partitions)

                  filtered[topic] = kept unless kept.empty?
                end

                if filtered.empty?
                  @clients.delete(client_name)
                else
                  @clients[client_name] = filtered
                end
              end
            end

            # @param client_name [String] rdkafka client name
            # @return [Hash, nil] refreshed data of a given client or nil when none
            def fetch(client_name)
              @mutex.synchronize do
                @clients[client_name]
              end
            end

            # Removes all the data of a given client. Used on rebalances as partitions may no
            # longer belong to the client that refreshed them.
            #
            # @param client_name [String] rdkafka client name
            def evict(client_name)
              @mutex.synchronize do
                @clients.delete(client_name)
              end
            end
          end
        end
      end
    end
  end
end

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
        module LagCompensation
          # Thread-safe storage for actively refreshed watermarks and lags of long-paused
          # partitions. Written by the refresher on listener threads, read by the statistics
          # decorator on the librdkafka callbacks thread.
          #
          # No age based expiry is needed: entries are refreshed while a partition stays paused,
          # kept (but no longer refreshed) once it resumes so the compensator can hand over to
          # the live statistics, and dropped in bulk on rebalances. Within an assignment the
          # stored set is therefore bounded by the partitions the client paused.
          class Registry
            include Singleton

            def initialize
              @mutex = Mutex.new
              @clients = {}
            end

            # Merges the freshly refreshed offsets into the stored data of a client, overwriting
            # the values of the refreshed partitions and keeping the previously stored ones.
            #
            # A refresh covers only the currently long-paused partitions, so a partition that
            # resumed is absent here and its last value is kept rather than dropped: the
            # compensator keeps overlaying it (its guard applies it only while still fresher than
            # the live statistics) until librdkafka post-resume fetches catch up, avoiding a
            # snap back to the frozen pre-resume values in the meantime. Stale entries are
            # dropped in bulk on the next rebalance.
            #
            # @param client_name [String] rdkafka client name (matches statistics `name` field)
            # @param data [Hash{String => Hash{Integer => Integer}}] topics with partitions
            #   with their end offsets
            def update(client_name, data)
              @mutex.synchronize do
                stored = (@clients[client_name] ||= {})

                data.each do |topic, partitions|
                  (stored[topic] ||= {}).merge!(partitions)
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

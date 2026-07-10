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
      # Active refreshing of watermarks and lags for long-paused partitions. librdkafka only
      # updates those values from fetch responses, so partitions paused for a long time report
      # frozen statistics. The refresher periodically fetches fresh values via the running
      # consumer connection and the decorator overlays them onto the emitted statistics.
      module PausedLags
        # Thread-safe storage for actively refreshed watermarks and lags of long-paused
        # partitions. Written by the refresher on listener threads, read by the statistics
        # decorator on the librdkafka callbacks thread.
        class Registry
          include Singleton
          include Karafka::Core::Helpers::Time

          def initialize
            @mutex = Mutex.new
            @clients = {}
          end

          # Stores refreshed data for a given client
          #
          # @param client_name [String] rdkafka client name (matches statistics `name` field)
          # @param data [Hash{String => Hash{Integer => Hash}}] topics with partitions with
          #   `:lo_offset`, `:hi_offset` and `:committed_offset` values
          def update(client_name, data)
            @mutex.synchronize do
              @clients[client_name] = { at: monotonic_now, data: data }
            end
          end

          # Returns refreshed data for a given client unless expired
          #
          # @param client_name [String] rdkafka client name
          # @param max_age [Integer] max age (ms) after which data is considered expired
          # @return [Hash, nil] refreshed data or nil when none or expired
          def fetch(client_name, max_age)
            @mutex.synchronize do
              entry = @clients[client_name]

              return unless entry
              return if monotonic_now - entry.fetch(:at) > max_age

              entry.fetch(:data)
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

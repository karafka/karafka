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
        module LagCompensation
          # Compensates stale offsets and lags of long-paused partitions in the raw librdkafka
          # statistics, using the actively refreshed values from the registry. When there is no
          # refreshed data for a given client, topic or partition, it does nothing, so values
          # from librdkafka remain untouched.
          #
          # It is pure and instant: all the broker queries happen in the refresher on the
          # listener threads, never on the librdkafka callbacks path.
          class Compensator
            # Compensates the statistics in place, so the standard decoration (deltas, freeze
            # durations) that runs afterwards operates on the compensated values as well
            #
            # @param statistics [Hash] raw librdkafka statistics
            def call(statistics)
              data = Registry.instance.fetch(statistics["name"])

              return unless data

              topics = statistics["topics"]

              return unless topics

              data.each do |topic, partitions|
                t_stats = topics[topic]

                next unless t_stats

                partitions.each do |partition, end_offset|
                  p_stats = t_stats["partitions"][partition.to_s]

                  next unless p_stats

                  compensate(p_stats, end_offset)
                end
              end
            end

            private

            # Compensates a single partition statistics with the refreshed end offset. The
            # committed and stored offsets are taken from the statistics themselves: they are
            # maintained by the client commits (not by fetches), so their values stay accurate
            # while a partition is paused and lags can be derived from them directly
            #
            # @param p_stats [Hash] single partition raw statistics
            # @param end_offset [Integer] refreshed partition end offset
            def compensate(p_stats, end_offset)
              # The end offset only grows, so a refreshed value older or equal to what
              # librdkafka reports means there is nothing to compensate: equal means no new
              # data in the topic since the last fetch and lower means the partition resumed
              # and its fetches are fresher than our refreshed snapshot. We compare against the
              # last stable offset as the refreshed end offset honors the consumer isolation
              # level.
              return unless end_offset > (p_stats["ls_offset"] || p_stats["hi_offset"] || -1)

              p_stats["ls_offset"] = end_offset
              # The real high watermark is always at least the last stable offset, so we bump
              # it when needed to keep the statistics internally consistent, never overstating
              hi_offset = p_stats["hi_offset"]
              p_stats["hi_offset"] = end_offset if hi_offset.nil? || end_offset > hi_offset

              committed = p_stats["committed_offset"]

              # Negative means nothing was committed yet for this partition, in which case lag
              # cannot be derived from the committed offset and we leave it untouched
              if committed && committed >= 0
                # Lags derive from the same reference the native librdkafka consumer lag does
                lag = end_offset - committed
                p_stats["consumer_lag"] = lag if lag >= 0
              end

              stored = p_stats["stored_offset"]

              return unless stored && stored >= 0

              lag_stored = end_offset - stored
              p_stats["consumer_lag_stored"] = lag_stored if lag_stored >= 0
            end
          end
        end
      end
    end
  end
end

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
      # Namespace for Pro instrumentation callbacks related components
      module Callbacks
        # Namespace for Pro consumer groups callbacks related components
        module ConsumerGroups
          # Pro statistics decorator for consumer groups. On top of the standard decoration
          # (deltas, freeze durations) it hosts Pro statistics enrichments. Currently it
          # overlays the actively refreshed watermarks and lags of long-paused partitions onto
          # the raw librdkafka statistics before the standard decoration. When there is no
          # refreshed data for a given client, topic or partition, it does nothing, so values
          # from librdkafka remain untouched.
          #
          # It is pure and instant: all the broker queries happen in the paused lags refresher
          # on the listener threads, never on the librdkafka callbacks path.
          class Decorator < Karafka::Instrumentation::Callbacks::ConsumerGroups::Decorator
            # @param statistics [Hash] raw librdkafka statistics
            # @return [Hash] decorated statistics with refreshed paused partitions data
            #
            # @note When the paused lags refreshing is disabled, the refresher is not
            #   subscribed and the registry stays empty, so the overlay is a pass-through by
            #   itself
            def call(statistics)
              overlay(statistics)

              super
            end

            private

            # Overlays refreshed values in place on the raw statistics so the standard
            # decoration (deltas, freeze durations) operates on the refreshed values as well
            #
            # @param statistics [Hash] raw librdkafka statistics
            def overlay(statistics)
              data = Pro::Instrumentation::ConsumerGroups::PausedLags::Registry
                .instance
                .fetch(statistics["name"])

              return unless data

              topics = statistics["topics"]

              return unless topics

              data.each do |topic, partitions|
                t_stats = topics[topic]

                next unless t_stats

                partitions.each do |partition, refreshed|
                  p_stats = t_stats["partitions"][partition.to_s]

                  next unless p_stats

                  hi_offset = refreshed.fetch(:hi_offset)

                  p_stats["lo_offset"] = refreshed.fetch(:lo_offset)
                  p_stats["hi_offset"] = hi_offset

                  committed = refreshed.fetch(:committed_offset)

                  # -1 means nothing was committed yet for this partition, in which case lag
                  # cannot be derived from the committed offset and we leave it untouched
                  if committed >= 0
                    p_stats["committed_offset"] = committed

                    lag = hi_offset - committed
                    p_stats["consumer_lag"] = lag if lag >= 0
                  end

                  stored = p_stats["stored_offset"]

                  next unless stored && stored >= 0

                  lag_stored = hi_offset - stored
                  p_stats["consumer_lag_stored"] = lag_stored if lag_stored >= 0
                end
              end
            end
          end
        end
      end
    end
  end
end

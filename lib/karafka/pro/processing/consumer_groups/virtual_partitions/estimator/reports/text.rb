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
    module Processing
      module ConsumerGroups
        module VirtualPartitions
          class Estimator
            # Estimator report renderers. They render a report parsed from the Estimator JSON
            # output, so they work on String keys and JSON values.
            module Reports
              # Renders an Estimator report as plain text
              class Text
                # Columns of the partitions table: header and the stats key
                COLUMNS = [
                  ["partition", nil],
                  ["messages", "messages"],
                  ["batches", "batches"],
                  ["avg VPs", "avg_active_vps"],
                  ["util %", "avg_utilization"],
                  ["imbalance %", "avg_load_imbalance"],
                  ["parallel %", "avg_parallelization"],
                  ["speedup", "avg_speedup"],
                  ["collapsed", "collapsed_batches"],
                  ["score", "score"],
                  ["verdict", "verdict"]
                ].freeze

                # Suggestions per verdict
                SUGGESTIONS = {
                  "recommended" => [
                    "Virtual Partitions should parallelize this data well."
                  ],
                  "maybe" => [
                    "Virtual Partitions may help, but the messages do not spread over all of them.",
                    "Try a partitioner on a more granular attribute."
                  ],
                  "not_recommended" => [
                    "Virtual Partitions are unlikely to help with this data.",
                    "In most batches a few keys hold most of the messages. Use a more granular " \
                    "partitioner or more Kafka partitions."
                  ]
                }.freeze

                # Suggestion when the verdict is not `recommended` and the `:balanced` distribution
                # would give a higher speedup than the `:consistent` one
                BALANCED_SUGGESTION = "Try the :balanced distribution, which gives a higher speedup " \
                  "for this data."

                # Suggestions when the partitioner raised in every batch, so each batch ran as one
                # group
                COLLAPSED_SUGGESTIONS = [
                  "The partitioner raised an error in every batch, so each batch was processed as " \
                  "one group.",
                  "Fix the partitioner and run the estimate again."
                ].freeze

                # Suggestions when an error was raised in every batch and a custom reducer was used
                # by the `:consistent` distribution, as such a reducer can also raise
                COLLAPSED_REDUCER_SUGGESTIONS = [
                  "The partitioner or the reducer raised an error in every batch, so each batch " \
                  "was processed as one group.",
                  "Fix the one that raised and run the estimate again."
                ].freeze

                # Suggestion when there is no score, because a concurrency below 2 parallelizes
                # nothing
                UNSCORED_SUGGESTIONS = [
                  "A concurrency below 2 runs each batch as one group, so nothing is parallelized."
                ].freeze

                # Limitations the estimate does not model
                CAVEATS = [
                  "The estimate assumes the same processing cost for each message.",
                  "The estimate assumes full batches. A consumer that is caught up gets smaller " \
                  "batches, which parallelize less.",
                  "The worker pool is shared with other partitions and topics."
                ].freeze

                private_constant(
                  :COLUMNS,
                  :SUGGESTIONS,
                  :BALANCED_SUGGESTION,
                  :COLLAPSED_SUGGESTIONS,
                  :COLLAPSED_REDUCER_SUGGESTIONS,
                  :UNSCORED_SUGGESTIONS,
                  :CAVEATS
                )

                # @param report [Hash] report parsed from JSON, so with String keys
                def initialize(report)
                  @report = report
                end

                # @return [String] multi-line plain text report
                def call
                  [
                    "Virtual Partitions estimate for topic: #{format_value(@report["topic_name"])}",
                    "",
                    "Settings:",
                    *(@report["settings"] || {}).map { |name, value| "  #{name}: #{format_value(value)}" },
                    "",
                    "Partitions:",
                    *table(@report["partitions"] || {}),
                    "",
                    "Summary:",
                    *summary(@report["summary"] || {}),
                    "",
                    "Caveats:",
                    *CAVEATS.map { |caveat| "  - #{caveat}" }
                  ].join("\n")
                end

                private

                # @param partitions [Hash{String => Hash}] partitions stats
                # @return [Array<String>] partitions table rows
                def table(partitions)
                  rows = partitions.sort_by { |partition, _| partition.to_i }.map do |partition, stats|
                    COLUMNS.map { |_, key| format_value(key ? stats[key] : partition) }
                  end

                  rows.unshift(COLUMNS.map(&:first))

                  widths = COLUMNS.each_index.map { |index| rows.map { |row| row[index].size }.max }

                  rows.map do |row|
                    "  " + row.each_with_index.map { |cell, index| cell.ljust(widths[index]) }
                      .join("  ").rstrip
                  end
                end

                # @param stats [Hash] summary stats
                # @return [Array<String>] summary lines
                def summary(stats)
                  return ["  No messages to analyze."] if stats["batches"].to_i.zero?

                  active_vps = stats["active_vps"] || {}
                  value = ->(key) { format_value(stats[key]) }

                  [
                    "  messages: #{value["messages"]}",
                    "  batches: #{value["batches"]} (collapsed: #{value["collapsed_batches"]}, " \
                    "poor: #{value["poor_batches"]}, single VP: #{value["single_vp_batches"]})",
                    "  avg unique keys per batch: #{value["avg_unique_keys"]}",
                    "  avg null keys per batch: #{value["avg_null_keys"]}",
                    "  active VPs: avg #{value["avg_active_vps"]}, " \
                    "min #{format_value(active_vps["min"])}, " \
                    "median #{format_value(active_vps["median"])}, " \
                    "max #{format_value(active_vps["max"])}",
                    "  avg utilization: #{value["avg_utilization"]}%",
                    "  avg load imbalance: #{value["avg_load_imbalance"]}%",
                    "  avg parallelization: #{value["avg_parallelization"]}%",
                    "  avg speedup: #{value["avg_speedup"]}x",
                    "  score: #{value["score"]}/100",
                    "  verdict: #{value["verdict"]}",
                    *suggestions(stats).map { |line| "  #{line}" }
                  ]
                end

                # @param stats [Hash] summary stats
                # @return [Array<String>] suggestions for the verdict
                def suggestions(stats)
                  return UNSCORED_SUGGESTIONS if stats["score"].nil?

                  if stats["collapsed_batches"] == stats["batches"]
                    return custom_reducer? ? COLLAPSED_REDUCER_SUGGESTIONS : COLLAPSED_SUGGESTIONS
                  end

                  suggestions = SUGGESTIONS.fetch(stats["verdict"], [])

                  return suggestions if stats["verdict"] == "recommended" || !balanced_faster?(stats)

                  [*suggestions, BALANCED_SUGGESTION]
                end

                # @return [Boolean] true when the `:consistent` distribution used a custom reducer
                def custom_reducer?
                  settings = @report["settings"] || {}

                  settings["custom_reducer"] == true && settings["distribution"] == "consistent"
                end

                # @param stats [Hash] summary stats
                # @return [Boolean] true when the `:balanced` distribution would give a higher
                #   speedup
                def balanced_faster?(stats)
                  stats["avg_balanced_speedup"].to_f > stats["avg_speedup"].to_f
                end

                # @param value [Object]
                # @return [String]
                def format_value(value)
                  value.nil? ? "-" : value.to_s
                end
              end
            end
          end
        end
      end
    end
  end
end

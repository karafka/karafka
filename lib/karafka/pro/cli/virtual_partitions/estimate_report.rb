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
    module Cli
      class VirtualPartitions < Karafka::Cli::Base
        # Displays a Virtual Partitions Estimator JSON report as plain text
        class EstimateReport
          # Report file read when no path is given
          DEFAULT_PATH = "report.json"

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
              "Virtual Partitions may help, but the keys do not spread evenly.",
              "Try a partitioner on a more granular attribute or the :balanced distribution."
            ],
            "not_recommended" => [
              "Virtual Partitions are unlikely to help with this data.",
              "Most batches use only a few keys. Use a more granular partitioner or more " \
              "Kafka partitions."
            ]
          }.freeze

          # Limitations the estimate does not model
          CAVEATS = [
            "The estimate assumes the same processing cost for each message.",
            "The worker pool is shared with other partitions and topics."
          ].freeze

          private_constant :DEFAULT_PATH, :COLUMNS, :SUGGESTIONS, :CAVEATS

          # @param path [String, nil] report file path. `report.json` in the current directory
          #   when nil.
          def initialize(path = nil)
            @path = path || DEFAULT_PATH
          end

          # Reads, validates and prints the report
          #
          # @raise [Karafka::Errors::CommandValidationError] when the file is missing, is not
          #   valid JSON, has an unsupported `format_version` or an invalid structure
          def call
            report = load_report

            puts(render(report))
          end

          private

          # @return [Hash] parsed and validated report
          def load_report
            content = begin
              File.read(@path)
            rescue SystemCallError
              fail!("Estimate report file not found: #{@path}")
            end

            report = begin
              JSON.parse(content)
            rescue JSON::ParserError
              fail!("Estimate report is not valid JSON: #{@path}")
            end

            expected = Processing::ConsumerGroups::VirtualPartitions::Estimator::FORMAT_VERSION
            found = report.is_a?(Hash) ? report.fetch("format_version", nil) : nil

            unless found.is_a?(Integer) && found == expected
              found = found.nil? ? "missing" : found.inspect

              fail!(
                "Unsupported estimate report format_version: #{found} (expected #{expected}). " \
                "Generate the report again with the Karafka version used to display it."
              )
            end

            fail!("Estimate report is not valid: #{@path}") unless valid_structure?(report)

            report
          end

          # @param report [Hash] parsed report
          # @return [Boolean] are all the sections the renderer reads Hashes when present
          def valid_structure?(report)
            partitions = report["partitions"]
            summary = report["summary"]

            optional_hash?(report["settings"]) &&
              optional_hash?(partitions) &&
              (partitions || {}).each_value.all? { |stats| stats.is_a?(Hash) } &&
              optional_hash?(summary) &&
              optional_hash?((summary || {})["active_vps"])
          end

          # @param value [Object]
          # @return [Boolean] is the value a Hash or nil
          def optional_hash?(value)
            value.nil? || value.is_a?(Hash)
          end

          # @param message [String]
          # @raise [Karafka::Errors::CommandValidationError]
          def fail!(message)
            raise Karafka::Errors::CommandValidationError, message
          end

          # @param report [Hash] parsed report
          # @return [String] multi-line plain text report
          def render(report)
            [
              "Virtual Partitions estimate for topic: #{format_value(report["topic_name"])}",
              "",
              "Settings:",
              *(report["settings"] || {}).map { |name, value| "  #{name}: #{format_value(value)}" },
              "",
              "Partitions:",
              *table(report["partitions"] || {}),
              "",
              "Summary:",
              *summary(report["summary"] || {}),
              "",
              "Caveats:",
              *CAVEATS.map { |caveat| "  - #{caveat}" }
            ].join("\n")
          end

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
              *SUGGESTIONS.fetch(stats["verdict"], []).map { |line| "  #{line}" }
            ]
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

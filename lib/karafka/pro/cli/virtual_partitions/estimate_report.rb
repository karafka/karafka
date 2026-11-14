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
        # Reads and validates a Virtual Partitions Estimator JSON report and prints it as plain text
        class EstimateReport
          # @param path [String, nil] report file path. When nil,
          #   `consumer_groups.virtual_partitions.estimator.report_file` is used.
          def initialize(path = nil)
            @path = path || Karafka::App.config.consumer_groups.virtual_partitions.estimator.report_file
          end

          # Reads, validates and prints the report
          #
          # @raise [SystemCallError] when the file cannot be read
          # @raise [JSON::ParserError] when the file is not valid JSON
          # @raise [Karafka::Errors::CommandValidationError] when the report has an unsupported
          #   `format_version` or an invalid structure
          def call
            report = load_report

            puts(Processing::ConsumerGroups::VirtualPartitions::Estimator::Reports::Text.new(report).call)
          end

          private

          # @return [Hash] parsed and validated report
          def load_report
            report = JSON.parse(File.read(@path))

            estimator = Processing::ConsumerGroups::VirtualPartitions::Estimator
            expected = estimator::FORMAT_VERSION
            found = report.is_a?(Hash) ? report.fetch("format_version", nil) : nil

            unless estimator::FormatComparator.new.call(found) == :current
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
          # @return [Boolean] are all the sections the renderer reads Hashes and the summary batches
          #   count an Integer when present
          def valid_structure?(report)
            partitions = report["partitions"]
            summary = report["summary"]

            optional_hash?(report["settings"]) &&
              optional_hash?(partitions) &&
              (partitions || {}).each_value.all? { |stats| stats.is_a?(Hash) } &&
              optional_hash?(summary) &&
              optional_hash?((summary || {})["active_vps"]) &&
              optional_integer?((summary || {})["batches"])
          end

          # @param value [Object]
          # @return [Boolean] is the value an Integer or nil
          def optional_integer?(value)
            value.nil? || value.is_a?(Integer)
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
        end
      end
    end
  end
end

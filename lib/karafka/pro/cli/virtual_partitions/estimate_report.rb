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
          # @raise [Karafka::Errors::CommandValidationError] when the report does not pass the
          #   `Contracts::EstimatorReport` contract
          def call
            report = load_report

            puts(Processing::ConsumerGroups::VirtualPartitions::Estimator::Reports::Text.new(report).call)
          end

          private

          # @return [Hash] parsed and validated report
          def load_report
            report = JSON.parse(File.read(@path))

            result = Processing::ConsumerGroups::VirtualPartitions::Contracts::EstimatorReport
              .new
              .call(report)

            return report if result.success?

            raise Karafka::Errors::CommandValidationError, result.errors
          end
        end
      end
    end
  end
end

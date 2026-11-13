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
      # CLI entry-point for Virtual Partitions related commands
      class VirtualPartitions < Karafka::Cli::Base
        desc "Allows for Virtual Partitions estimate reports display"

        aliases :vps

        # Exit code when the command fails
        ERROR_EXIT_CODE = 1

        private_constant :ERROR_EXIT_CODE

        # @param action [String] action we want to take
        def call(action = "estimate-report")
          case action
          when "estimate-report"
            EstimateReport.new(report_path).call
          when "help"
            Help.new.call
          else
            raise(
              Karafka::Errors::UnrecognizedCommandError,
              "Unrecognized virtual partitions action: #{action}"
            )
          end
        rescue Karafka::Errors::CommandValidationError => e
          puts e.message
          exit(ERROR_EXIT_CODE)
        end

        private

        # @return [String, nil] report path given after the action
        def report_path
          ARGV[2].to_s.start_with?("-") ? nil : ARGV[2]
        end
      end
    end
  end
end

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
            # Compares the `format_version` of an estimation report with the one the current
            # Karafka version builds, so a report built by another version is not rendered
            # with a structure it does not have.
            class FormatComparator
              # @param format_version [Object] `format_version` read from the report
              # @return [Symbol] `:older`, `:newer` or `:current` when the version is an Integer,
              #   `:unknown` otherwise (missing or of another type)
              def call(format_version)
                return :unknown unless format_version.is_a?(Integer)
                return :older if format_version < FORMAT_VERSION
                return :newer if format_version > FORMAT_VERSION

                :current
              end
            end
          end
        end
      end
    end
  end
end

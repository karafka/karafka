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
    # Namespace for Pro setup components
    module Setup
      # Pro defaults injector that extends the OSS defaults with Pro-specific settings
      module DefaultsInjector
        # Pro-specific consumer kafka defaults
        # These defaults are carefully tuned to work with Pro's internal statistics aggregation,
        # the Web UI dashboard, and the performance tracker. They depend on Pro's extended
        # instrumentation pipeline and should not be applied outside of Pro as they may cause
        # incomplete or inconsistent metrics collection and other unexpected behaviours.
        CONSUMER_KAFKA_DEFAULTS = {
          "statistics.unassigned.include": false
        }.freeze

        private_constant :CONSUMER_KAFKA_DEFAULTS

        # Pro actively manages these keys via its own DefaultsInjector so users are allowed
        # to set them if needed.
        #
        # @return [Set<Symbol>] empty set since Pro handles these keys
        def managed_keys
          @managed_keys ||= Set.new
        end

        # Enriches consumer kafka config with Pro-specific defaults
        # @param kafka_config [Hash] kafka scoped config
        def consumer(kafka_config)
          super

          CONSUMER_KAFKA_DEFAULTS.each do |key, value|
            next if kafka_config.key?(key)

            kafka_config[key] = value
          end
        end
      end
    end
  end
end

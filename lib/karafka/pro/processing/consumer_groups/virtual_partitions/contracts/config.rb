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
          module Contracts
            # Makes sure the Virtual Partitions config is defined as it should be
            class Config < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load_file(
                  File.join(Karafka.gem_root, "config", "locales", "pro_errors.yml")
                ).fetch("en").fetch("validations").fetch("setup").fetch("config")
              end

              nested(:consumer_groups) do
                nested(:virtual_partitions) do
                  nested(:estimator) do
                    required(:sample_size) { |val| val.is_a?(Integer) && val >= 1 }
                    required(:distribution) { |val| %i[consistent balanced].include?(val) }
                    required(:report_file) { |val| val.is_a?(String) && !val.empty? }
                    required(:recommended_score) { |val| val.is_a?(Integer) && val.between?(0, 100) }
                    required(:maybe_score) { |val| val.is_a?(Integer) && val.between?(0, 100) }

                    nested(:score_weights) do
                      required(:utilization) { |val| val.is_a?(Integer) && val >= 0 }
                      required(:parallelization) { |val| val.is_a?(Integer) && val >= 0 }
                      required(:balance) { |val| val.is_a?(Integer) && val >= 0 }
                      required(:stability) { |val| val.is_a?(Integer) && val >= 0 }
                    end
                  end
                end
              end

              # The maybe verdict needs to be below the recommended one
              virtual do |data, errors|
                next unless errors.empty?

                estimator = data.fetch(:consumer_groups).fetch(:virtual_partitions).fetch(:estimator)

                next if estimator.fetch(:maybe_score) <= estimator.fetch(:recommended_score)

                [[%i[consumer_groups virtual_partitions estimator maybe_score], :above_recommended]]
              end

              # Scores are in the 0-100 range only when the weights sum up to 100
              virtual do |data, errors|
                next unless errors.empty?

                estimator = data.fetch(:consumer_groups).fetch(:virtual_partitions).fetch(:estimator)

                next if estimator.fetch(:score_weights).values.sum == 100

                [[%i[consumer_groups virtual_partitions estimator score_weights], :sum]]
              end
            end
          end
        end
      end
    end
  end
end

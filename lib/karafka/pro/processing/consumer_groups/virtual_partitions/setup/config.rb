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
          # Setup and config related Virtual Partitions components
          module Setup
            # Config for Virtual Partitions
            class Config
              extend Karafka::Core::Configurable

              # Virtual Partitions Estimator defaults
              setting(:estimator) do
                # Number of most recent messages to sample per partition
                setting(:sample_size, default: 10_000)

                # Distribution to estimate for (`:consistent` or `:balanced`)
                setting(:distribution, default: :consistent)

                # Report file (String or Pathname) `karafka vps estimate-report` reads when no path is
                # given
                setting(:report_file, default: "report.json")

                # Minimum score for the `:recommended` verdict
                setting(:recommended_score, default: 70)

                # Minimum score for the `:maybe` verdict
                setting(:maybe_score, default: 40)

                # Weights of the score components. They need to sum up to 100.
                setting(:score_weights) do
                  setting(:utilization, default: 40)
                  setting(:parallelization, default: 30)
                  setting(:balance, default: 20)
                  setting(:stability, default: 10)
                end
              end

              configure
            end
          end
        end
      end
    end
  end
end

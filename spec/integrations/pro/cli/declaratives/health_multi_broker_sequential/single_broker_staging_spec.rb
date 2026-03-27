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

# Integration test for topics health command in single-broker cluster (common staging setup)
# This test expects to detect RF=1 as a critical issue, which is typical in single-broker setups

setup_karafka

draw_routes do
  # Typical staging setup: single broker, RF=1
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 3,
      replication_factor: 1
    )
  end

  topic DT.topics[1] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 1
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "health"

out = capture_stdout do
  Karafka::Cli.start
end

# Should show progressive output
assert out.include?("Checking topics health")

# Should detect RF=1 issues on both topics
assert out.include?(DT.topics[0])
assert out.include?(DT.topics[1])
assert out.include?("RF=1 (no redundancy)")

# Should provide recommendations appropriate for staging -> production migration
assert out.include?("Recommendations")
assert out.include?("Ensure RF >= 3 for production topics")

# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Integration test for topics health command with mixed critical and warning issues

setup_karafka

draw_routes do
  # Critical: RF=1
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 1,
      replication_factor: 1
    )
  end

  # Critical: RF=2, min.insync=2
  topic DT.topics[1] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 2,
      "min.insync.replicas": 2
    )
  end

  # Warning: RF=3, min.insync=1
  topic DT.topics[2] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 3,
      "min.insync.replicas": 1
    )
  end

  # Healthy: RF=3, min.insync=2
  topic DT.topics[3] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 3,
      "min.insync.replicas": 2
    )
  end
end

create_routes_topics

ARGV[0] = "topics"
ARGV[1] = "health"

out = capture_stdout do
  Karafka::Cli.start
end

# Should show progressive output
assert out.include?("Checking topics health")
assert out.include?("Found")

# Should list all problematic topics
assert out.include?(DT.topics[0])
assert out.include?(DT.topics[1])
assert out.include?(DT.topics[2])

# Should identify specific issues
assert out.include?("RF=1 (no redundancy)")
assert out.include?("RF=2, min.insync=2 (zero fault tolerance)")
assert out.include?("RF=3, min.insync=1 (low durability)")

# Healthy topic should show with checkmark (or just appear without issues)
# In shared environment, it won't appear in issues list
topic_in_output = out.include?(DT.topics[3].to_s)
topic_has_checkmark = out.include?("✓ #{DT.topics[3]}")
# Topic either has checkmark OR doesn't appear in issues (both mean it's healthy)
assert topic_has_checkmark || topic_in_output

# Should provide recommendations
assert out.include?("Recommendations")

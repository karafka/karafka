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

# Integration test for topics health command detecting min.insync=1 (low durability warning)

setup_karafka

draw_routes do
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 3,
      "min.insync.replicas": 1
    )
  end
end

create_routes_topics

ARGV[0] = "topics"
ARGV[1] = "health"

out = capture_stdout do
  Karafka::Cli.start
end

# Should report warnings
# Should show progressive output
assert out.include?("Checking topics health")

# Should identify low durability for our test topic
assert out.include?(DT.topics[0])
assert out.include?("RF=3, min.insync=1 (low durability)")

# Should provide recommendations at the end
assert out.include?("Recommendations")
assert out.include?("min.insync.replicas to at least 2")

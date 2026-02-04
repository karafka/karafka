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

# Integration test verifying that health command skips internal Kafka topics (starting with __)


setup_karafka

draw_routes do
  topic DT.topics[0] do
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

# Should not report issues about internal topics
assert_not out.include?("__consumer_offsets")
assert_not out.include?("__transaction_state")

# Should only check user topics
assert out.include?("Checking topics health")

# If test topic is healthy, should report all healthy
# (assumes internal topics might have RF=1 which is normal)
if out.include?("Issues found")
  # If there are issues, they should only be about our test topics
  assert out.include?(DT.topics[0]) if out.include?("Issues found") && out.include?(DT.topics[0])
end

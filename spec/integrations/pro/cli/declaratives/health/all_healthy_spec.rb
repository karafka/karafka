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

# Integration test for topics health command when all topics are healthy

require "integrations_helper"

setup_karafka

# This test requires at least 3 brokers for RF=3
cluster_info = Karafka::Admin.cluster_info
broker_count = cluster_info.brokers.size
exit 0 unless broker_count >= 3

draw_routes do
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 3,
      replication_factor: 3,
      "min.insync.replicas": 2
    )
  end

  topic DT.topics[1] do
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

# Should indicate all topics are healthy
assert out.include?("All topics are healthy")
assert out.include?("Checking topics health")

# Should not show any issues
assert_not out.include?("Issues found")
assert_not out.include?("Critical")
assert_not out.include?("Warnings")

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

# Integration test for topics health command with --detailed-exitcode when all topics are healthy


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
ARGV[2] = "--detailed-exitcode"

exit_code = nil

out = capture_stdout do
  # Should exit with 0 (no issues)
  Karafka::Cli.start
  exit_code = 0
rescue SystemExit => e
  exit_code = e.status
end

assert_equal 0, exit_code

assert out.include?("All topics are healthy")

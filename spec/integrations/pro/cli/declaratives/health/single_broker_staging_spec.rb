# frozen_string_literal: true

# Integration test for topics health command in single-broker cluster (common staging setup)
# This test expects to detect RF=1 as a critical issue, which is typical in single-broker setups

require "integrations_helper"

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

create_routes_topics

ARGV[0] = "topics"
ARGV[1] = "health"

out = capture_stdout do
  Karafka::Cli.start
end

# Should detect RF=1 issues on both topics
assert out.include?("Issues found")
assert out.include?("Critical")
assert out.include?(DT.topics[0])
assert out.include?(DT.topics[1])
assert out.include?("RF=1 (no redundancy)")

# Should provide recommendations appropriate for staging -> production migration
assert out.include?("Recommendations")
assert out.include?("Ensure RF >= 3 for production topics")

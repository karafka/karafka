# frozen_string_literal: true

# Integration test for topics health command when all topics are healthy

require "integrations_helper"

setup_karafka

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

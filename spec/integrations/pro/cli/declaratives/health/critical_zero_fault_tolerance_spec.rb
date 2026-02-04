# frozen_string_literal: true

# Integration test for topics health command detecting RF <= min.insync (zero fault tolerance)

require "integrations_helper"

setup_karafka

draw_routes do
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 2,
      replication_factor: 2,
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

# Should report critical issues
assert out.include?("Issues found")
assert out.include?("Critical")

# Should identify zero fault tolerance
assert out.include?(DT.topics[0])
assert out.include?("RF=2, min.insync=2 (zero fault tolerance)")

# Should provide recommendations
assert out.include?("Recommendations")
assert out.include?("RF > min.insync.replicas")

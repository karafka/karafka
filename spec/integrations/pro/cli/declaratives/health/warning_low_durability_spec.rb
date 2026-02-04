# frozen_string_literal: true

# Integration test for topics health command detecting min.insync=1 (low durability warning)

require "integrations_helper"

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
assert out.include?("Issues found")
assert out.include?("Warnings")

# Should identify low durability
assert out.include?(DT.topics[0])
assert out.include?("RF=3, min.insync=1 (low durability)")

# Should NOT show critical issues
assert_not out.include?("Critical:")

# Should provide recommendations
assert out.include?("min.insync.replicas to at least 2")

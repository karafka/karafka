# frozen_string_literal: true

# Integration test for topics health command with mixed critical and warning issues

require "integrations_helper"

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

# Should report both critical and warnings
assert out.include?("Issues found")
assert out.include?("Critical:")
assert out.include?("Warnings:")

# Should list all problematic topics
assert out.include?(DT.topics[0])
assert out.include?(DT.topics[1])
assert out.include?(DT.topics[2])

# Should identify specific issues
assert out.include?("RF=1 (no redundancy)")
assert out.include?("RF=2, min.insync=2 (zero fault tolerance)")
assert out.include?("RF=3, min.insync=1 (low durability)")

# Healthy topic should not be listed
assert_not out.include?(DT.topics[3])

# Should provide recommendations
assert out.include?("Recommendations")

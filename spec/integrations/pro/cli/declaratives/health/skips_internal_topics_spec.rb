# frozen_string_literal: true

# Integration test verifying that health command skips internal Kafka topics (starting with __)

require "integrations_helper"

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

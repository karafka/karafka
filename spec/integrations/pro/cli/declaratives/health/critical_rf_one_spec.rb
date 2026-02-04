# frozen_string_literal: true

# Integration test for topics health command detecting RF=1 (no redundancy)

require "integrations_helper"

setup_karafka

draw_routes do
  topic DT.topics[0] do
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

# Should report issues
assert out.include?("Issues found")
assert out.include?("Critical")

# Should identify the specific issue
assert out.include?(DT.topics[0])
assert out.include?("RF=1 (no redundancy)")

# Should provide recommendations
assert out.include?("Recommendations")
assert out.include?("Ensure RF >= 3")

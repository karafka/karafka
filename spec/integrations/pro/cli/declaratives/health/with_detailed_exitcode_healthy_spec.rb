# frozen_string_literal: true

# Integration test for topics health command with --detailed-exitcode when all topics are healthy

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

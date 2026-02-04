# frozen_string_literal: true

# Integration test for topics health command with --detailed-exitcode when issues are found

require "integrations_helper"

setup_karafka

draw_routes do
  topic DT.topics[0] do
    consumer Class.new
    config(
      partitions: 1,
      replication_factor: 1
    )
  end
end

create_routes_topics

ARGV[0] = "topics"
ARGV[1] = "health"
ARGV[2] = "--detailed-exitcode"

exit_code = nil

out = capture_stdout do
  # Should exit with 2 (issues found)
  Karafka::Cli.start
  exit_code = 0
rescue SystemExit => e
  exit_code = e.status
end

assert_equal 2, exit_code
assert out.include?("Issues found")
assert out.include?(DT.topics[0])

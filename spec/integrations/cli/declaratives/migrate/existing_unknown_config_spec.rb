# frozen_string_literal: true

# karafka topics migrate should fail when an existing topic has configuration unknown to the
# cluster instead of skipping it silently

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 1,
      "retention.msx": 86_400_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "migrate"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("#{DT.topic} has configuration unknown to the cluster: retention.msx.")
assert !results.include?("no configurations to align")

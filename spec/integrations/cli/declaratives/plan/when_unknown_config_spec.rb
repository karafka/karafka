# frozen_string_literal: true

# karafka topics plan should report configuration unknown to the cluster of an existing topic as
# not applicable and fail, instead of listing it as a pending change

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 1,
      "retention.msx": 86_400_000,
      "retention.bytes": 1_000_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("Following topics configuration is unknown to the cluster")
assert results.include?('retention.msx: "86400000"')
assert results.include?("Following topics will have configuration changes:")
assert results.include?("retention.bytes:")
assert !results.include?("retention.msx: \"\"")

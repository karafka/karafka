# frozen_string_literal: true

# karafka topics align should skip a topic that does not exist even when it has configuration
# unknown to the cluster, and still align the existing ones

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(
      partitions: 1,
      "retention.bytes": 1_000_000
    )
  end

  topic DT.topics[1] do
    active false
    config(
      partitions: 1,
      "retention.msx": 86_400_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

results = capture_stdout do
  Karafka::Cli.start
end

assert results.include?("topic #{DT.topics[1]} does not exist.")
assert results.include?("Updated")
assert !results.include?("unknown to the cluster")

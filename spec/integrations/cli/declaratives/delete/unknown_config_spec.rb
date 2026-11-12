# frozen_string_literal: true

# karafka topics delete should fail when a topic has configuration unknown to the cluster, and
# should not delete any topic

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(partitions: 1)
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
ARGV[1] = "delete"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }

assert_equal 1, DT[:status]
assert results.include?("#{DT.topics[1]} has configuration unknown to the cluster: retention.msx.")
assert topics_names.include?(DT.topics[0])
assert topics_names.include?(DT.topics[1])

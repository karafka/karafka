# frozen_string_literal: true

# karafka topics migrate should fail before creating anything when a topic that would be created
# has configuration unknown to the cluster

setup_karafka

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
ARGV[1] = "migrate"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }

assert_equal 1, DT[:status]
assert results.include?("configuration unknown to the cluster: retention.msx")
assert !topics_names.include?(DT.topics[0])
assert !topics_names.include?(DT.topics[1])

# frozen_string_literal: true

# karafka topics reset should fail when a topic has configuration unknown to the cluster, and
# should not delete any topic

setup_karafka

Karafka::Admin.create_topic(DT.topic, 2, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 5,
      "retention.msx": 86_400_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "reset"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

assert_equal 1, DT[:status]
assert results.include?("#{DT.topic} has configuration unknown to the cluster: retention.msx.")
assert_equal 2, cluster_topics.fetch(DT.topic)

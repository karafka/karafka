# frozen_string_literal: true

# karafka topics repartition should fail when a topic that does not exist has configuration
# unknown to the cluster, and should not repartition the existing ones

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(partitions: 5)
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
ARGV[1] = "repartition"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

assert_equal 1, DT[:status]
assert results.include?("#{DT.topics[1]} has configuration unknown to the cluster: retention.msx.")
assert_equal 1, cluster_topics.fetch(DT.topics[0])
assert !cluster_topics.key?(DT.topics[1])

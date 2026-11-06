# frozen_string_literal: true

# karafka topics migrate should fail on configuration unknown to the cluster before it creates or
# repartitions any topic

setup_karafka

Karafka::Admin.create_topic(DT.topics[1], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(partitions: 1)
  end

  topic DT.topics[1] do
    active false
    config(
      partitions: 3,
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
assert results.include?("#{DT.topics[1]} has configuration unknown to the cluster: retention.msx.")

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

assert !cluster_topics.key?(DT.topics[0])
assert_equal 1, cluster_topics.fetch(DT.topics[1])

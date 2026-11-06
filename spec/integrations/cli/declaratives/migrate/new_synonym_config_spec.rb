# frozen_string_literal: true

# karafka topics migrate should fail before creating anything when a topic that would be created
# uses a broker synonym config name, as topic creation does not accept synonyms

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 1,
      "log.retention.bytes": 1_000_000
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
assert results.include?("configuration unknown to the cluster: log.retention.bytes")
assert !results.include?("Creating topic")
assert !topics_names.include?(DT.topic)

# frozen_string_literal: true

# karafka topics reset should fail before deleting anything when an existing topic uses a synonym
# config name, as creating the topic again would not accept it

setup_karafka

Karafka::Admin.create_topic(DT.topic, 2, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 2,
      "log.retention.bytes": 1_000_000
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

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }

assert_equal 1, DT[:status]
assert results.include?("#{DT.topic} has configuration unknown to the cluster: log.retention.bytes.")
assert !results.include?("Deleted")
assert topics_names.include?(DT.topic)

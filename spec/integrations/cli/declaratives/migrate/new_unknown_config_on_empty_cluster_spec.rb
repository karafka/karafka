# frozen_string_literal: true

# karafka topics migrate should fail before creating anything when a topic that would be created
# has configuration unknown to the cluster and the cluster has no topic to read the known
# configuration from

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

# Makes the cluster look empty, as we cannot use one without any topic
module EmptyCluster
  def cluster_info
    info = super
    info.topics.clear if DT[:empty]
    info
  end
end

Karafka::Admin.prepend(EmptyCluster)

ARGV[0] = "topics"
ARGV[1] = "migrate"

DT[:empty] = true

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

DT[:empty] = false

topics_names = Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }

assert_equal 1, DT[:status]
assert results.include?("configuration unknown to the cluster: retention.msx")
assert !topics_names.include?(DT.topics[0])
assert !topics_names.include?(DT.topics[1])

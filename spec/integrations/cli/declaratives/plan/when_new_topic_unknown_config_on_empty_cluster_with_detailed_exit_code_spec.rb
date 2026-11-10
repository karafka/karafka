# frozen_string_literal: true

# karafka topics plan with detailed exit code should exit with 1 (error) and not 2 (changes) when
# a topic that would be created has configuration unknown to the cluster and the cluster has no
# topic to read the known configuration from

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 2,
      "retention.msx": 86_400_000,
      "retention.ms": 86_400_000,
      "log.retention.bytes": 1_000
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
ARGV[1] = "plan"
ARGV[2] = "--detailed-exitcode"

DT[:empty] = true

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

DT[:empty] = false

assert_equal 1, DT[:status]
assert results.include?("Following topics will be created:")
assert results.include?("Following topics configuration is unknown to the cluster")
assert_equal 1, results.scan('retention.msx: "86400000"').size
assert_equal 1, results.scan('log.retention.bytes: "1000"').size
assert results.include?('retention.ms: "86400000"')
assert !Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }.include?(DT.topic)

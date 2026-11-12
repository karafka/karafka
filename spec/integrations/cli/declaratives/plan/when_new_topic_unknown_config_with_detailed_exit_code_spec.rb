# frozen_string_literal: true

# karafka topics plan with detailed exit code should exit with 1 (error) and not 2 (changes) when
# a topic that would be created has configuration unknown to the cluster

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(
      partitions: 2,
      "retention.msx": 86_400_000,
      "retention.ms": 86_400_000
    )
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"
ARGV[2] = "--detailed-exitcode"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("Following topics will be created:")
assert results.include?('retention.ms: "86400000"')
assert results.include?("Following topics configuration is unknown to the cluster")
assert_equal 1, results.scan('retention.msx: "86400000"').size
assert !Karafka::Admin.cluster_info.topics.map { |topic| topic[:topic_name] }.include?(DT.topic)

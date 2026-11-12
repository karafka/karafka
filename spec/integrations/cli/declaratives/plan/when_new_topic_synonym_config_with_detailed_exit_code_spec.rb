# frozen_string_literal: true

# karafka topics plan with detailed exit code should exit with 1 (error) and not 2 (changes) when
# a topic that would be created uses a broker synonym config name, as topic creation does not
# accept synonyms

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
ARGV[1] = "plan"
ARGV[2] = "--detailed-exitcode"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("Following topics configuration is unknown to the cluster")
assert_equal 1, results.scan('log.retention.bytes: "1000000"').size

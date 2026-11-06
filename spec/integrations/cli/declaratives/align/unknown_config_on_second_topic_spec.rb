# frozen_string_literal: true

# karafka topics align should fail on a configuration unknown to the cluster also when only a topic
# other than the first existing one has it

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 1, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(partitions: 1, "retention.bytes": 1_000_000)
  end

  topic DT.topics[1] do
    active false
    config(partitions: 1, "retention.msx": 86_400_000)
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

results = capture_stdout do
  Karafka::Cli.start
rescue SystemExit => e
  DT[:status] = e.status
end

assert_equal 1, DT[:status]
assert results.include?("#{DT.topics[1]} has configuration unknown to the cluster: retention.msx.")
assert !results.include?(DT.topics[0])
assert !results.include?("Updated")

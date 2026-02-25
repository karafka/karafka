# frozen_string_literal: true

# When declarative topics exist but no changes needed as the config is the same, we should not
# print changes details

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 2, 1)
Karafka::Admin.create_topic(DT.topics[1], 2, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    # This retention should be cluster default for this to work
    config(partitions: 2, "retention.ms": 604_800_000)
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"

results = capture_stdout do
  Karafka::Cli.start
end

%w[
  9223372036854775807
  9223372036854
  max.compaction.lag.ms:
  max.message.bytes:
  max.message.bytes:
  retention.bytes:
  retention.ms:
  1000000
  9223372036854775802
  message.timestamp.after.max.ms
].each do |part|
  assert !results.include?(part), part
end

assert !results.include?("Following topics will have configuration changes:")
assert results.include?("perform any actions. No changes needed.")

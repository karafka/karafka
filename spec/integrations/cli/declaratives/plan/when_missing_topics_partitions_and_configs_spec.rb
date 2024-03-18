# frozen_string_literal: true

# Declaratives should work when multiple things are changing

setup_karafka

Karafka::Admin.create_topic(DT.topics[1], 5, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(
      partitions: 2,
      'max.compaction.lag.ms': '9223372036854',
      'max.message.bytes': '100000'
    )
  end

  topic DT.topics[1] do
    active false
    config(
      partitions: 6,
      'message.timestamp.after.max.ms': '9223372036854775802',
      'retention.bytes': '1000000'
    )
  end

  topic DT.topics[2] do
    active false
    config(active: false)
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'plan'

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
  1000000
  9223372036854775802
  message.timestamp.after.max.ms
].each do |part|
  assert results.include?(part)
end

assert results.include?('Following topics will have configuration changes:')
assert !results.include?('perform any actions. No changes needed.')
assert results.include?('Following topics will be created:')
assert results.include?('Following topics will be repartitioned:')
assert results.include?(DT.topics[0])
assert results.include?(DT.topics[1])
assert !results.include?(DT.topics[2])

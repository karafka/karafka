# frozen_string_literal: true

# When declarative topics exist with config request, it should work even if the same attribute
# is defined multiple times as long as the last value is a change
# Proper name should be used and not alias and value from last used (which is alias)

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 2, 1)
Karafka::Admin.create_topic(DT.topics[1], 5, 1)

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    config(
      partitions: 2,
      'log.retention.bytes': -1,
      'retention.bytes': 100_000
    )
  end

  topic DT.topics[1] do
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
  100000
  retention.bytes
].each do |part|
  assert results.include?(part)
end

assert !results.include?('log.retention.bytes')
assert results.include?('Following topics will have configuration changes:')
assert !results.include?('perform any actions. No changes needed.')
assert !results.include?('Following topics will be created:')
assert !results.include?('Following topics will be repartitioned:')
assert results.include?(DT.topics[0])
assert !results.include?(DT.topics[1])

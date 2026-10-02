# frozen_string_literal: true

# When declarative topics exist but no changes needed it should exit with 0 when detailed exit code
# is enabled

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 2, 1)
Karafka::Admin.create_topic(DT.topics[1], 2, 1)

draw_topics(create_topics: false) do
  topic(DT.topics[0]) do
    partitions 2
    config("retention.ms": 604_800_000)
  end
end

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active false
    # This retention should be cluster default for this to work
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"
ARGV[2] = "--detailed-exitcode"

Karafka::Cli.start

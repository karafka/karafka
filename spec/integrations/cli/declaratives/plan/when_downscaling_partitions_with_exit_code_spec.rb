# frozen_string_literal: true

# When declarative topic exists but has more partitions than declared, we should exit with 0 when
# detailed exit code is on because no changes will be applied

setup_karafka

Karafka::Admin.create_topic(DT.topic, 5, 1)

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(partitions: 2)
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"
ARGV[2] = "--detailed_exitcode"

Karafka::Cli.start

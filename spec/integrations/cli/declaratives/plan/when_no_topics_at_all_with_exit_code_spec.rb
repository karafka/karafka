# frozen_string_literal: true

# When no declarative topics, we should exit with 0 on detailed exit code

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topic do
    active false
    config(active: false)
  end
end

ARGV[0] = "topics"
ARGV[1] = "plan"
ARGV[2] = "--detailed_exitcode"

Karafka::Cli.start

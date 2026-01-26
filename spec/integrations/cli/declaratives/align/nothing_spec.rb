# frozen_string_literal: true

# karafka topics align should do nothing when no declarative topics

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active(false)
  end

  topic DT.topics[1] do
    active(false)
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

Karafka::Cli.start

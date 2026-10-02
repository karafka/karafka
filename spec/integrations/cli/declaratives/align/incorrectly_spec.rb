# frozen_string_literal: true

# karafka topics align should crash if we want to align something with incorrect changes
# Please note this is NOT transactional. It will crash and exit 1.

setup_karafka

# We create them with defaults first so they have default settings that will be altered by
# declaratives

Karafka::Admin.create_topic(DT.topics[0], 1, 1)

draw_topics(create_topics: false) do
  topic(DT.topics[0]) do
    partitions 1
    config(
      "retention.ms": "-100",
      "cleanup.policy": "delete"
    )
  end
end

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    active(false)
  end
end

ARGV[0] = "topics"
ARGV[1] = "align"

Karafka::Cli.start

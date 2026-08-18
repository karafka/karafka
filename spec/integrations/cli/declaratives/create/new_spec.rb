# frozen_string_literal: true

# karafka topics create should create topics when defined in routing

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Don't use the specs topics auto-bootstrap feature
# We disable it because we want to test the CLI action for this
draw_topics(create_topics: false) do
  topic(DT.topics[0])

  topic(DT.topics[1]) do
    partitions 2
    config("cleanup.policy": "compact")
  end
end

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "create"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

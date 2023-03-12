# frozen_string_literal: true

# karafka topics create should create topics when defined in routing

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# Don't use the specs topics auto-bootstrap feature
# We disable it because we want to test the CLI action for this
draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    config(
      partitions: 2,
      'cleanup.policy': 'compact'
    )

    consumer Consumer
  end
end

Karafka::Cli.start %w[topics create]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

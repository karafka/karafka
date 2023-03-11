# frozen_string_literal: true

# karafka topics create should skip topics that already exist

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes do
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

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

# This should not remove nor change the topics
# Since the `draw_routes` auto-creator
Karafka::Cli.start %w[topics create]

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

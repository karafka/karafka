# frozen_string_literal: true

# karafka topics create should not create topics when defined in routing but with opted out
# config setup

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    config(active: false)
    consumer Consumer
  end

  topic DT.topics[1] do
    config(active: false)
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "create"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert !cluster_topics.include?(DT.topics[0])
assert !cluster_topics.include?(DT.topics[1])

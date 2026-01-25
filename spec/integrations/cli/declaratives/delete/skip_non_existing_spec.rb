# frozen_string_literal: true

# karafka topics delete should skip non-existing topics defined in routes and nothing should break

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "delete"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map { |topic| topic.fetch(:topic_name) }

assert !cluster_topics.include?(DT.topics[0])
assert !cluster_topics.include?(DT.topics[1])

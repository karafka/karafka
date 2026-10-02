# frozen_string_literal: true

# karafka topics delete should not delete existing topics defined in routes but opted out

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

# This will create them automatically
draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

clear_app_draws

draw_topics(create_topics: false) do
  topic(DT.topics[0]) do
    active false
  end

  topic(DT.topics[1]) do
    active false
  end
end

draw_routes do
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

assert cluster_topics.include?(DT.topics[0])
assert cluster_topics.include?(DT.topics[1])

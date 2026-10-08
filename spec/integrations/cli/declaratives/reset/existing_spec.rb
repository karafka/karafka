# frozen_string_literal: true

# karafka topics reset should delete and re-create topics defined in routes

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_topics(create_topics: false) do
  topic(DT.topic) do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

clear_app_draws

draw_topics(create_topics: false) do
  topic(DT.topic) do
    partitions 5
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "reset"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

assert_equal 5, cluster_topics.fetch(DT.topic)

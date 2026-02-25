# frozen_string_literal: true

# karafka topics repartition should not increase number of partitions if less than what we want but
# the topic is opted out

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 1)
    consumer Consumer
  end
end

Karafka::App.routes.clear

draw_routes(create_topics: false) do
  topic DT.topic do
    config(partitions: 5, active: false)
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "repartition"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

assert_equal 1, cluster_topics.fetch(DT.topic)

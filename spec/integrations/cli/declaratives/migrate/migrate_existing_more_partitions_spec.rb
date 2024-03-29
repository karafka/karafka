# frozen_string_literal: true

# karafka topics migrate should repartition topics when defined in routing, existing and not
# enough partitions

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
    config(partitions: 5)
    consumer Consumer
  end
end

ARGV[0] = 'topics'
ARGV[1] = 'repartition'

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.map do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end.to_h

# Increase
assert_equal 5, cluster_topics.fetch(DT.topic)

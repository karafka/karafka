# frozen_string_literal: true

# karafka topics migrate should do nothing when all stays the same

Karafka::Cli.prepare

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes do
  topic DT.topic do
    config(partitions: 5)
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

Karafka::Cli.start %w[topics repartition]

cluster_topics = Karafka::Admin.cluster_info.topics.map do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end.to_h

# Increase
assert_equal 5, cluster_topics.fetch(DT.topic)

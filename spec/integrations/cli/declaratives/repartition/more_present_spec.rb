# frozen_string_literal: true

# karafka topics repartition should do nothing, when there are already more partitions or equal
# number of them

Consumer = Class.new(Karafka::BaseConsumer)

setup_karafka

draw_routes do
  topic DT.topics[0] do
    config(partitions: 5)
    consumer Consumer
  end

  topic DT.topics[1] do
    config(partitions: 5)
    consumer Consumer
  end
end

Karafka::App.routes.clear

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    # Same number of partitions
    config(partitions: 5)
    consumer Consumer
  end

  topic DT.topics[1] do
    # Less than what exists
    config(partitions: 1)
    consumer Consumer
  end
end

ARGV[0] = "topics"
ARGV[1] = "repartition"

Karafka::Cli.start

cluster_topics = Karafka::Admin.cluster_info.topics.to_h do |topic|
  [topic.fetch(:topic_name), topic.fetch(:partition_count)]
end

# No change
assert_equal 5, cluster_topics.fetch(DT.topics[0])
# No downsize or anything
assert_equal 5, cluster_topics.fetch(DT.topics[1])

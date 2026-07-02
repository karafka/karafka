# frozen_string_literal: true

# The `draw_topics` spec helper should declare topic structure independently from routing and
# eagerly create the declared topics on the cluster with the requested partition count - without
# any routing entry being defined.

setup_karafka

draw_topics do
  topic DT.topics[0] do
    partitions 3
  end

  topic DT.topics[1] do
    partitions 1
    config("cleanup.policy": "compact")
  end
end

# Both declarations live in the shared repository
assert_equal 3, Karafka::App.declaratives.find_topic(DT.topics[0]).partitions
assert_equal({ "cleanup.policy": "compact" }, Karafka::App.declaratives.find_topic(DT.topics[1]).details)

# And both topics were actually created on the cluster with the requested partition counts
created = Karafka::Admin.cluster_info.topics.each_with_object({}) do |topic, accu|
  accu[topic.fetch(:topic_name)] = topic.fetch(:partition_count)
end

assert_equal 3, created.fetch(DT.topics[0])
assert_equal 1, created.fetch(DT.topics[1])

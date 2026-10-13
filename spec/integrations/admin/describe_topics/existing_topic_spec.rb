# frozen_string_literal: true

# Karafka::Admin.describe_topic should return the topic id and every partition with its leader,
# replicas and in-sync replicas.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 3, 1)

topic = Karafka::Admin.describe_topic(DT.topic)
broker_ids = Karafka::Admin.cluster_info.brokers.map { |broker| broker[:broker_id] }

assert_equal DT.topic, topic[:name]
assert_equal nil, topic[:error]
assert topic[:topic_id].is_a?(String), topic
assert_equal false, topic[:internal]
assert_equal [0, 1, 2], topic[:partitions].map { |partition| partition[:partition] }

topic[:partitions].each do |partition|
  assert broker_ids.include?(partition[:leader][:id]), partition
  assert_equal [partition[:leader][:id]], partition[:replicas].map { |replica| replica[:id] }
  assert_equal [partition[:leader][:id]], partition[:isr].map { |replica| replica[:id] }
end

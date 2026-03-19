# frozen_string_literal: true

# When querying affected partitions for a broker, we should get back all
# __consumer_offsets partitions led by that broker.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

metadata = Karafka::Admin.cluster_info
first_broker = metadata.brokers.first
broker_id = first_broker.is_a?(Hash) ? (first_broker[:broker_id] || first_broker[:node_id]) : first_broker.node_id

result = Karafka::Admin::Recovery.affected_partitions(broker_id)

# Should be a sorted array
assert result.is_a?(Array), "Expected Array, got #{result.class}"
assert_equal result, result.sort

# In a single-broker dev cluster, this broker leads all 50 partitions
# In multi-broker clusters, it leads some subset
assert !result.empty?, "Expected at least one partition led by broker #{broker_id}"

# All returned partition numbers should be valid
offsets_topic = metadata.topics.find { |t| t[:topic_name] == "__consumer_offsets" }
partition_count = offsets_topic[:partition_count]

result.each do |p|
  assert p >= 0 && p < partition_count,
    "Partition #{p} out of range (0...#{partition_count})"
end

# Non-existent broker should return empty array
empty_result = Karafka::Admin::Recovery.affected_partitions(99999)
assert_equal [], empty_result

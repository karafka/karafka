# frozen_string_literal: true

# When looking up the coordinator for a consumer group, we should get back
# valid broker information matching the real cluster.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

GROUP_ID = SecureRandom.uuid

result = Karafka::Admin::Recovery.coordinator_for(GROUP_ID)

# Should return the expected partition
expected_partition = Karafka::Admin::Recovery.offsets_partition_for(GROUP_ID)
assert_equal expected_partition, result[:partition]

# broker_id should be a non-negative integer
assert result[:broker_id] >= 0, "Expected non-negative broker_id, got #{result[:broker_id]}"

# broker_host should have host:port format
assert result[:broker_host].match?(/\A.+:\d+\z/),
       "Expected host:port format, got #{result[:broker_host]}"

# Verify the broker actually exists in cluster metadata
metadata = Karafka::Admin.cluster_info
broker_ids = metadata.brokers.map do |b|
  b.is_a?(Hash) ? (b[:broker_id] || b[:node_id]) : b.node_id
end

assert broker_ids.include?(result[:broker_id]),
       "Broker #{result[:broker_id]} not found in cluster"

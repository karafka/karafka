# frozen_string_literal: true

# When scanning a __consumer_offsets partition for affected groups, we should
# discover all consumer groups that have committed offsets on that partition.

setup_karafka

draw_routes do
  topic DT.topics[0] do
    active false
    config(partitions: 2)
  end
end

GROUP1 = SecureRandom.uuid
GROUP2 = SecureRandom.uuid

# Commit offsets for both groups
Karafka::Admin::ConsumerGroups.seek(GROUP1, { DT.topics[0] => { 0 => 10 } })
Karafka::Admin::ConsumerGroups.seek(GROUP2, { DT.topics[0] => { 0 => 20 } })

sleep(2)

# Find which partition each group maps to
partition1 = Karafka::Admin::Recovery.offsets_partition_for(GROUP1)
partition2 = Karafka::Admin::Recovery.offsets_partition_for(GROUP2)

# Scan the partition for GROUP1 - it should at least contain GROUP1
result1 = Karafka::Admin::Recovery.affected_groups(partition1, lookback_ms: 60 * 1_000)
assert result1.include?(GROUP1), "Expected to find #{GROUP1} on partition #{partition1}"

# If both groups happen to be on the same partition, both should appear
if partition1 == partition2
  assert result1.include?(GROUP2), "Expected to find #{GROUP2} on same partition"
else
  result2 = Karafka::Admin::Recovery.affected_groups(partition2, lookback_ms: 60 * 1_000)
  assert result2.include?(GROUP2), "Expected to find #{GROUP2} on partition #{partition2}"
end

# Result should be sorted
assert_equal result1, result1.sort

# frozen_string_literal: true

# offsets_partition_for should return a valid partition number for the __consumer_offsets topic,
# be deterministic for the same input, and produce different results for different inputs.

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

# Get the real __consumer_offsets partition count from cluster metadata
offsets_topic_info = Karafka::Admin.cluster_info.topics.find do |t|
  t[:topic_name] == "__consumer_offsets"
end

partition_count = offsets_topic_info[:partition_count]

# Should return a value within the valid partition range
result = Karafka::Admin::Recovery.offsets_partition_for("test-group")
assert result >= 0, "Partition should be >= 0"
assert result < partition_count, "Partition should be < #{partition_count}"

# Should be deterministic
first_call = Karafka::Admin::Recovery.offsets_partition_for("my-consumer-group")
second_call = Karafka::Admin::Recovery.offsets_partition_for("my-consumer-group")
assert_equal first_call, second_call

# Different group names should (generally) produce different partitions
partitions = %w[
  group-alpha group-beta group-gamma group-delta group-epsilon
  group-zeta group-eta group-theta group-iota group-kappa
].map { |g| Karafka::Admin::Recovery.offsets_partition_for(g) }

unique_count = partitions.uniq.size
assert unique_count > 1, "Expected different groups to map to different partitions, got all #{partitions.first}"

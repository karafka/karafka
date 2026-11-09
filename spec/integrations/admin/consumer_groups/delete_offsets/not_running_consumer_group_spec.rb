# frozen_string_literal: true

# Deleting committed offsets of a consumer group without members should remove them only for the
# requested topics and partitions, leaving its other offsets in place.

setup_karafka

draw_topics do
  topic DT.topics[0] do
    partitions 2
  end

  topic DT.topics[1] do
    partitions 2
  end
end

DT.topics.first(2).each do |topic|
  2.times { |partition| produce_many(topic, DT.uuids(10), partition: partition) }
end

Karafka::Admin.seek_consumer_group(
  DT.group,
  {
    DT.topics[0] => { 0 => 3, 1 => 4 },
    DT.topics[1] => { 0 => 5, 1 => 6 }
  }
)

Karafka::Admin.delete_consumer_group_offsets(
  DT.group,
  { DT.topics[0] => [0, 1], DT.topics[1] => [1] }
)

offsets = Karafka::Admin
  .read_lags_with_offsets({ DT.group => DT.topics.first(2) })
  .fetch(DT.group)
  .transform_values { |partitions| partitions.transform_values { |details| details[:offset] } }

assert_equal({ 0 => -1, 1 => -1 }, offsets.fetch(DT.topics[0]))
assert_equal({ 0 => 5, 1 => -1 }, offsets.fetch(DT.topics[1]))

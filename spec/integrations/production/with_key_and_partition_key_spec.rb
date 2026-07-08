# frozen_string_literal: true

# When using both key and partition key to target partition, partition key should take precedence

setup_karafka(allow_errors: true)

draw_topics do
  topic DT.topics[0] do
    partitions 10
  end
end

draw_routes do
  topic DT.topics[0] do
    active false
  end
end

result = Karafka.producer.produce_sync(
  topic: DT.topics[0],
  payload: nil,
  # This alone would target partition 6
  key: "test",
  # This will target partition 4
  partition_key: "12345"
)

assert_equal 4, result.partition, result.partition

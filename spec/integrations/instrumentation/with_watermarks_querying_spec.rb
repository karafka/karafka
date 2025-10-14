# frozen_string_literal: true

# Karafka should be able to query watermark offsets for multiple topics and partitions
# using a single consumer instance

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    # Nothing to do, we're just testing Admin API
  end
end

# Create three topics with different partition counts
topic1 = "#{DT.topic}-1"
topic2 = "#{DT.topic}-2"
topic3 = "#{DT.topic}-3"

draw_routes do
  topic topic1 do
    consumer Consumer
    config(partitions: 2)
  end

  topic topic2 do
    consumer Consumer
    config(partitions: 3)
  end

  topic topic3 do
    consumer Consumer
    config(partitions: 1)
  end
end

# Produce messages to some partitions but not all
produce(topic1, '1', partition: 0)
produce(topic1, '2', partition: 0)
produce(topic1, '3', partition: 1)

produce(topic2, '1', partition: 0)
produce(topic2, '2', partition: 1)
produce(topic2, '3', partition: 1)
produce(topic2, '4', partition: 1)
# topic2 partition 2 has no messages

produce(topic3, '1', partition: 0)
produce(topic3, '2', partition: 0)
produce(topic3, '3', partition: 0)
produce(topic3, '4', partition: 0)
produce(topic3, '5', partition: 0)

# Query watermarks for multiple topics and partitions
result = Karafka::Admin.read_watermark_offsets(
  topic1 => [0, 1],
  topic2 => [0, 1, 2],
  topic3 => [0]
)

# Verify topic1 results
assert_equal [0, 2], result[topic1][0], 'topic1 partition 0 should have 2 messages'
assert_equal [0, 1], result[topic1][1], 'topic1 partition 1 should have 1 message'

# Verify topic2 results
assert_equal [0, 1], result[topic2][0], 'topic2 partition 0 should have 1 message'
assert_equal [0, 3], result[topic2][1], 'topic2 partition 1 should have 3 messages'
assert_equal [0, 0], result[topic2][2], 'topic2 partition 2 should have no messages'

# Verify topic3 results
assert_equal [0, 5], result[topic3][0], 'topic3 partition 0 should have 5 messages'

# Verify that only the requested topics and partitions are in the result
assert_equal [topic1, topic2, topic3].sort, result.keys.sort
assert_equal [0, 1], result[topic1].keys.sort
assert_equal [0, 1, 2], result[topic2].keys.sort
assert_equal [0], result[topic3].keys.sort

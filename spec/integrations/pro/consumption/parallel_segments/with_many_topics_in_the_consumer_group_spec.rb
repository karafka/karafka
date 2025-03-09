# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# With many topics in the consumer group, they all should work correctly and work should be
# distributed as expected.

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    topic_name = topic.name

    messages.each do |message|
      DT[:assignments] << [topic_name, message.key, segment_id]
      DT[segment_id] << message.raw_payload
      DT["#{segment_id}-#{topic_name}"] << message.raw_payload
    end
  end
end

topics = DT.topics.first(5)

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topics.each do |topic_name|
      topic topic_name do
        consumer Consumer
      end
    end
  end
end

# Create a consistent set of keys that will distribute deterministically
group0_keys = []
group1_keys = []
group2_keys = []

# Generate 30 keys (10 for each segment)
30.times do |i|
  key = "key-#{i}"

  group_id = key.to_s.sum % 3

  case group_id
  when 0
    group0_keys << key
  when 1
    group1_keys << key
  when 2
    group2_keys << key
  end
end

# Prepare messages for each topic - using same keys to verify consistency
all_messages = []

topics.each do |topic_name|
  # Add messages for segment 0
  group0_keys.each do |key|
    all_messages << {
      topic: topic_name,
      key: key,
      payload: "#{topic_name}-#{key}"
    }
  end

  # Add messages for segment 1
  group1_keys.each do |key|
    all_messages << {
      topic: topic_name,
      key: key,
      payload: "#{topic_name}-#{key}"
    }
  end

  # Add messages for segment 2
  group2_keys.each do |key|
    all_messages << {
      topic: topic_name,
      key: key,
      payload: "#{topic_name}-#{key}"
    }
  end
end

# Produce all messages
Karafka::App.producer.produce_many_sync(all_messages)

start_karafka_and_wait_until do
  # Wait until we've processed expected number of messages
  # 30 messages per topic × 5 topics = 150 total messages
  DT[:assignments].size >= 150
end

# Verify assignments are consistent across topics
topic_assignments = {}

# Group assignments by topic and key
DT[:assignments].each do |topic, key, segment|
  topic_assignments[topic] ||= {}
  topic_assignments[topic][key] = segment
end

# Verify the same key is assigned to the same segment across all topics
inconsistent_keys = []

topics.each do |topic1|
  next unless topic_assignments[topic1]

  topics.each do |topic2|
    next if topic1 == topic2 || !topic_assignments[topic2]

    # Find keys that exist in both topics
    common_keys = topic_assignments[topic1].keys & topic_assignments[topic2].keys

    common_keys.each do |key|
      next if topic_assignments[topic1][key] == topic_assignments[topic2][key]

      inconsistent_keys << [
        key,
        topic1,
        topic2,
        topic_assignments[topic1][key],
        topic_assignments[topic2][key]
      ]
    end
  end
end

assert_equal(
  [],
  inconsistent_keys,
  "Some keys were assigned to different segments across topics: #{inconsistent_keys}"
)

# Verify each segment processed the expected number of messages
total_segment0 = DT[0].size
total_segment1 = DT[1].size
total_segment2 = DT[2].size

# Each segment should have processed its keys across all topics
expected_segment0 = group0_keys.size * topics.size
expected_segment1 = group1_keys.size * topics.size
expected_segment2 = group2_keys.size * topics.size

assert_equal(
  expected_segment0,
  total_segment0,
  "Segment 0 processed #{total_segment0} messages, expected #{expected_segment0}"
)

assert_equal(
  expected_segment1,
  total_segment1,
  "Segment 1 processed #{total_segment1} messages, expected #{expected_segment1}"
)

assert_equal(
  expected_segment2,
  total_segment2,
  "Segment 2 processed #{total_segment2} messages, expected #{expected_segment2}"
)

# Verify each segment processed messages from all topics
topics.each do |topic_name|
  # Check segment 0 processed messages from this topic
  segment0_topic_count = DT["0-#{topic_name}"].size
  assert_equal(
    group0_keys.size,
    segment0_topic_count,
    "Segment 0 processed #{segment0_topic_count} from #{topic_name}, expected #{group0_keys.size}"
  )

  # Check segment 1 processed messages from this topic
  segment1_topic_count = DT["1-#{topic_name}"].size
  assert_equal(
    group1_keys.size,
    segment1_topic_count,
    "Segment 1 processed #{segment1_topic_count} from #{topic_name}, expected #{group1_keys.size}"
  )

  # Check segment 2 processed messages from this topic
  segment2_topic_count = DT["2-#{topic_name}"].size
  assert_equal(
    group2_keys.size,
    segment2_topic_count,
    "Segment 2 processed #{segment2_topic_count} from #{topic_name}, expected #{group2_keys.size}"
  )
end

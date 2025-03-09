# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Parallel segments should work correctly with dynamically matched topics from patterns

setup_karafka do |config|
  config.kafka[:'topic.metadata.refresh.interval.ms'] = 2_000
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      DT[:assignments] << [message.key, segment_id, message.metadata.topic]
      DT[segment_id] << message.raw_payload
    end
  end
end

pattern_base = SecureRandom.hex(4)
topic_pattern = /#{pattern_base}-.*-topic/

draw_routes(create_topics: false) do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 2,
      partitioner: ->(message) { message.raw_key }
    )

    pattern(:parallel_pattern, topic_pattern) do
      consumer Consumer
    end
  end
end

# Generate unique keys that will be distributed deterministically
group0_keys = []
group1_keys = []

50.times do |i|
  key = "key-#{i}"

  # Determine which group this key will go to based on sum % 2
  if (key.to_s.sum % 2).zero?
    group0_keys << key
  else
    group1_keys << key
  end
end

# Take a subset of keys for each topic
topic1_group0_keys = group0_keys[0..9]
topic1_group1_keys = group1_keys[0..9]
topic2_group0_keys = group0_keys[10..19]
topic2_group1_keys = group1_keys[10..19]

# Start Karafka and wait for pattern detection and message processing
start_karafka_and_wait_until do
  unless @created_topic1
    # Wait a bit for Karafka to initialize
    sleep(5)

    # Create first dynamically matched topic
    topic1 = "#{pattern_base}-first-topic"

    # Create and send messages to first topic
    messages1 = []

    topic1_group0_keys.each do |key|
      messages1 << { topic: topic1, key: key, payload: "topic1-#{key}" }
    end

    topic1_group1_keys.each do |key|
      messages1 << { topic: topic1, key: key, payload: "topic1-#{key}" }
    end

    Karafka::App.producer.produce_many_sync(messages1)

    @created_topic1 = true
    @topic1 = topic1
  end

  # Check if first topic's messages were processed
  first_topic_processed = DT[0].size + DT[1].size >= 20

  # Only create second topic after first is processed
  if first_topic_processed && !@created_topic2
    # Create second dynamically matched topic
    topic2 = "#{pattern_base}-second-topic"

    # Create and send messages to second topic
    messages2 = []

    topic2_group0_keys.each do |key|
      messages2 << { topic: topic2, key: key, payload: "topic2-#{key}" }
    end

    topic2_group1_keys.each do |key|
      messages2 << { topic: topic2, key: key, payload: "topic2-#{key}" }
    end

    # Produce messages to second topic
    Karafka::App.producer.produce_many_sync(messages2)

    @created_topic2 = true
    @topic2 = topic2
  end

  # Wait until all messages from both topics are processed
  first_topic_processed && @created_topic2 && DT[0].size + DT[1].size >= 40
end

# Verify that each segment received messages
assert !DT[0].empty?, 'Segment 0 should have received messages'
assert !DT[1].empty?, 'Segment 1 should have received messages'

# Verify that both topics were matched and consumed
topics = Karafka::App.consumer_groups.first.topics.map(&:name)
assert topics.include?(@topic1), 'First topic should be matched and added to routing'
assert topics.include?(@topic2), 'Second topic should be matched and added to routing'

# Extract assignments by topic and key
topic1_assignments = {}
topic2_assignments = {}

DT[:assignments].each do |key, segment_id, topic|
  if topic == @topic1
    topic1_assignments[key] = segment_id
  elsif topic == @topic2
    topic2_assignments[key] = segment_id
  end
end

# Verify consistent assignment of same keys across different topics
common_keys = topic1_assignments.keys & topic2_assignments.keys

common_keys.each do |key|
  assert_equal(
    topic1_assignments[key],
    topic2_assignments[key],
    "Key #{key} should be assigned to the same segment in both topics"
  )
end

# Verify segment counts match expected distribution
segment0_topic1 = DT[:assignments].count { |_, segment, topic| segment == 0 && topic == @topic1 }
segment1_topic1 = DT[:assignments].count { |_, segment, topic| segment == 1 && topic == @topic1 }
segment0_topic2 = DT[:assignments].count { |_, segment, topic| segment == 0 && topic == @topic2 }
segment1_topic2 = DT[:assignments].count { |_, segment, topic| segment == 1 && topic == @topic2 }

# Distribution should match our pre-calculated key groups
assert_equal(
  topic1_group0_keys.size,
  segment0_topic1,
  'Segment 0 received wrong number of messages for topic 1'
)

assert_equal(
  topic1_group1_keys.size,
  segment1_topic1,
  'Segment 1 received wrong number of messages for topic 1'
)

assert_equal(
  topic2_group0_keys.size,
  segment0_topic2,
  'Segment 0 received wrong number of messages for topic 2'
)

assert_equal(
  topic2_group1_keys.size,
  segment1_topic2,
  'Segment 1 received wrong number of messages for topic 2'
)

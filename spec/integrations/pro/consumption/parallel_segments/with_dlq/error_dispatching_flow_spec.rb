# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Error dispatching to DLQ should respect the parallel segment group assignment using
# segment-specific DLQ topics

setup_karafka(allow_errors: %w[consumer.consume.error])

# Define a DLQ strategy that dispatches to segment-specific DLQ topics
class SegmentSpecificDlqStrategy
  def call(errors_tracker, attempt)
    consumer_group = errors_tracker.topic.consumer_group
    segment_id = consumer_group.segment_id

    # Track decision for verification
    DT[:dlq_decisions] << {
      segment_id: segment_id,
      consumer_group: consumer_group.name,
      attempt: attempt
    }

    # Return the appropriate DLQ topic based on segment ID
    [:dispatch, "#{DT.topics[1]}-#{segment_id}"]
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      # Track processing with key and segment information
      DT[:processing] << {
        key: message.key,
        segment_id: segment_id,
        attempt: attempt
      }

      # Store which segment got which key for verification
      DT[:key_segment_map][message.key] = segment_id
    end

    # Always raise an error to trigger DLQ
    raise StandardError, "Error from segment #{segment_id}"
  end
end

DT[:dlq_topics] = Set.new

class DlqConsumer < Karafka::BaseConsumer
  def consume
    # Extract segment ID from topic name
    segment_id = topic.name.split('-').last.to_i

    # Track messages in the DLQ
    messages.each do |message|
      DT[:dlq_received] << {
        key: message.key,
        dlq_topic: topic.name,
        segment_id: segment_id
      }
    end

    # Track DLQ topics for final assertion
    DT[:dlq_topics] << topic.name
  end
end

draw_routes do
  # Main consumer group with parallel segments
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topics[0] do
      consumer Consumer
      dead_letter_queue(
        topic: :strategy,
        strategy: SegmentSpecificDlqStrategy.new
      )
    end
  end

  # DLQ topics for each segment
  3.times do |segment_id|
    topic "#{DT.topics[1]}-#{segment_id}" do
      consumer DlqConsumer
    end
  end
end

# Create messages that will map to specific segments
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for each segment
10.times do |i|
  [0, 1, 2].each do |segment_id|
    # Create a key that maps to this segment
    key = nil

    (0..100).each do |j|
      candidate = "key-seg#{segment_id}-#{i}-#{j}"

      if candidate.to_s.sum % 3 == segment_id
        key = candidate
        break
      end
    end

    segment_messages[segment_id] << {
      topic: DT.topics[0],
      key: key,
      payload: "payload-for-segment-#{segment_id}-#{i}"
    }
  end
end

# Initialize mapping for actual key-to-segment assignments
DT[:key_segment_map] = {}

# Produce all messages
all_messages = segment_messages.values.flatten
Karafka::App.producer.produce_many_sync(all_messages)

# Start Karafka and wait until we've received messages in all DLQ topics
start_karafka_and_wait_until do
  # We want to see messages in all 3 segment-specific DLQ topics
  DT[:dlq_topics].size >= 3
end

# 1. Verify DLQ routing decisions happened for each segment
[0, 1, 2].each do |segment_id|
  decisions = DT[:dlq_decisions].select { |d| d[:segment_id] == segment_id }

  assert(
    !decisions.empty?,
    "No DLQ routing decisions were made for segment #{segment_id}"
  )
end

# 2. Verify messages were routed to the appropriate segment-specific DLQ topic
DT[:dlq_received].each do |record|
  key = record[:key]
  dlq_segment_id = record[:segment_id]

  # We need to check if we have processing data for this key first
  next unless DT[:key_segment_map].key?(key)

  source_segment_id = DT[:key_segment_map][key]

  assert_equal(
    source_segment_id,
    dlq_segment_id,
    "Message with key #{key} from #{source_segment_id} was sent to DLQ for #{dlq_segment_id}"
  )
end

# 3. Verify all segment-specific DLQ topics received messages
expected_dlq_topics = Array.new(3) { |i| "#{DT.topics[1]}-#{i}" }.sort

assert_equal(
  expected_dlq_topics.sort,
  DT[:dlq_topics].to_a.sort,
  'Not all expected DLQ topics received messages'
)

# 4. Verify segments only processed keys assigned to them
processed_by_segment = {}
DT[:processing].each do |record|
  segment_id = record[:segment_id]
  processed_by_segment[segment_id] ||= []
  processed_by_segment[segment_id] << record[:key]
end

# Check each segment's DLQ contains only keys originally processed by that segment
[0, 1, 2].each do |segment_id|
  dlq_topic = "#{DT.topics[1]}-#{segment_id}"

  # Get keys that ended up in this DLQ topic
  dlq_keys = DT[:dlq_received].select { |r| r[:dlq_topic] == dlq_topic }.map { |r| r[:key] }

  # Skip if no keys were processed for this segment
  next if processed_by_segment[segment_id].nil? || processed_by_segment[segment_id].empty?

  # Verify DLQ keys were originally processed by this segment
  dlq_keys.each do |key|
    # Check if we have data for this key
    next unless DT[:key_segment_map].key?(key)

    source_segment = DT[:key_segment_map][key]

    assert_equal(
      segment_id,
      source_segment,
      "Key #{key} in DLQ topic #{dlq_topic} was originally processed by #{source_segment}"
    )
  end
end

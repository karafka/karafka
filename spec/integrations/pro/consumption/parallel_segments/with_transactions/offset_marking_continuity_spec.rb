# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Offset marking within transactions should maintain continuity in parallel segments

setup_karafka do |config|
  config.concurrency = 10
  config.kafka[:'transactional.id'] = SecureRandom.uuid
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    batch_id = SecureRandom.hex(4)

    transaction do
      messages.each do |message|
        # Track the message processing with transaction info
        DT[:processed] << {
          key: message.key,
          segment_id: segment_id,
          batch_id: batch_id,
          payload: message.raw_payload,
          offset: message.offset
        }

        # Produce to a target topic within the transaction
        produce_async(
          topic: DT.topics[1], # Use second topic as target
          key: message.key,
          payload: "processed-#{message.raw_payload}"
        )
      end

      # Explicitly mark last message as consumed within transaction
      mark_as_consumed(messages.last)
    end
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )

    topic DT.topics[0] do # Source topic
      consumer Consumer
    end
  end
end

# Create messages that will be distributed across 3 parallel segments
segment0_messages = []
segment1_messages = []
segment2_messages = []

30.times do |i|
  key = "key-#{i}"
  segment_id = key.to_s.sum % 3
  payload = "payload-#{i}"

  message = {
    topic: DT.topics[0],
    key: key,
    payload: payload
  }

  case segment_id
  when 0
    segment0_messages << message
  when 1
    segment1_messages << message
  when 2
    segment2_messages << message
  end
end

# Produce all messages
all_messages = segment0_messages + segment1_messages + segment2_messages
all_messages.shuffle!
Karafka::App.producer.produce_many_sync(all_messages)

start_karafka_and_wait_until do
  DT[:processed].size >= 30
end

# 1. Verify each segment processed its expected messages
by_segment = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  by_segment[segment_id] ||= []
  by_segment[segment_id] << record
end

# Each segment should have processed roughly 10 messages
assert(by_segment[0].size >= 9, "Segment 0 processed too few messages: #{by_segment[0].size}")
assert(by_segment[1].size >= 9, "Segment 1 processed too few messages: #{by_segment[1].size}")
assert(by_segment[2].size >= 9, "Segment 2 processed too few messages: #{by_segment[2].size}")

# 2. Verify messages are processed according to segment assignment
processed_keys_by_segment = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  key = record[:key]
  processed_keys_by_segment[segment_id] ||= []
  processed_keys_by_segment[segment_id] << key
end

processed_keys_by_segment.each do |segment_id, keys|
  keys.each do |key|
    expected_segment = key.to_s.sum % 3
    assert_equal(
      expected_segment,
      segment_id,
      "Key #{key} was processed by #{segment_id} should have been by #{expected_segment}"
    )
  end
end

# 3. Verify transactions work correctly by checking that each batch is either fully processed or
# not at all
by_batch = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  batch_id = record[:batch_id]
  by_batch[segment_id] ||= {}
  by_batch[segment_id][batch_id] ||= []
  by_batch[segment_id][batch_id] << record
end

# For each batch, we check the source record keys were all processed correctly
by_batch.each do |segment_id, batches|
  batches.each do |batch_id, records|
    # All records in this batch should belong to this segment
    records.each do |record|
      expected_segment = record[:key].to_s.sum % 3
      assert_equal(
        expected_segment,
        segment_id,
        "Batch #{batch_id}:" \
        " Key #{record[:key]} processed by #{segment_id} but should #{expected_segment}"
      )
    end
  end
end

# 4. Get committed offsets for all segments
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

segment0_offset = fetch_next_offset(DT.topics[0], consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topics[0], consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topics[0], consumer_group_id: segment2_group_id)

# All segments should have committed offsets
assert(segment0_offset > 0, 'Segment 0 did not commit any offsets')
assert(segment1_offset > 0, 'Segment 1 did not commit any offsets')
assert(segment2_offset > 0, 'Segment 2 did not commit any offsets')

# 5. Verify consumer lag - with parallel segments, some lag is expected since each segment
# only processes a subset of messages
offsets_with_lags = Karafka::Admin.read_lags_with_offsets
segment0_lag = offsets_with_lags.fetch(segment0_group_id).fetch(DT.topics[0])[0].fetch(:lag)
segment1_lag = offsets_with_lags.fetch(segment1_group_id).fetch(DT.topics[0])[0].fetch(:lag)
segment2_lag = offsets_with_lags.fetch(segment2_group_id).fetch(DT.topics[0])[0].fetch(:lag)

# With parallel segments, each segment will report lag for messages assigned to other segments
# So the lag should be roughly 2/3 of total messages (assuming even distribution)
max_expected_lag = all_messages.size * 0.7

assert(
  segment0_lag <= max_expected_lag,
  "Segment 0 has excessive lag: #{segment0_lag}, max expected: #{max_expected_lag}"
)
assert(
  segment1_lag <= max_expected_lag,
  "Segment 1 has excessive lag: #{segment1_lag}, max expected: #{max_expected_lag}"
)
assert(
  segment2_lag <= max_expected_lag,
  "Segment 2 has excessive lag: #{segment2_lag}, max expected: #{max_expected_lag}"
)

# 6. Verify that the target topic has all the expected produced messages
# Set up a consumer to count produced records in the target topic
consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topics[1])

produced_messages = []
max_polls = 100
polls = 0

while produced_messages.size < 30 && polls < max_polls
  message = consumer.poll(1000)

  if message
    produced_messages << {
      key: message.key,
      payload: message.payload
    }
  end

  polls += 1
end

consumer.close

assert_equal(
  30,
  produced_messages.size,
  "Target topic should contain exactly 30 produced messages, found #{produced_messages.size}"
)

# 7. Verify no duplicate messages in target topic (exactly-once semantics maintained)
unique_produced_messages = produced_messages.uniq
assert_equal(
  produced_messages.size,
  unique_produced_messages.size,
  'Target topic contains duplicate messages, indicating transaction failures'
)

# 8. Verify all messages from each segment are successfully processed
segment_keys = {}
segment_keys[0] = segment0_messages.map { |m| m[:key] }.sort
segment_keys[1] = segment1_messages.map { |m| m[:key] }.sort
segment_keys[2] = segment2_messages.map { |m| m[:key] }.sort

processed_keys = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  processed_keys[segment_id] ||= []
  processed_keys[segment_id] << record[:key]
end

[0, 1, 2].each do |segment_id|
  processed_segment_keys = processed_keys[segment_id].sort.uniq
  expected_segment_keys = segment_keys[segment_id]

  assert_equal(
    expected_segment_keys,
    processed_segment_keys,
    "Segment #{segment_id} should process exactly its assigned keys"
  )
end

# 9. Verify all transactions succeeded (all offsets committed, all messages produced)
# If any transaction failed, we'd see missing messages or consumer lag
total_processed = DT[:processed].size
assert_equal(
  30,
  total_processed,
  "Expected 30 messages to be processed, but found #{total_processed}"
)

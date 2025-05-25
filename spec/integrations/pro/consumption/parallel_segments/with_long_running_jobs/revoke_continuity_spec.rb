# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# After partition revocation, reacquired partitions should resume with consistent parallel segment
# assignment

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 1
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

# Subscribe to the revocation notification event
Karafka.monitor.subscribe('consumer.revoked') do |event|
  DT[:revoked_events] << event
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    message_key = messages.first.key

    # Track message processing with segment and partition information
    DT[:processed] << {
      key: message_key,
      segment_id: segment_id,
      offset: messages.first.offset,
      partition: messages.metadata.partition,
      before_rebalance: DT[:rebalanced].empty?
    }

    # Store message for verification
    DT[segment_id] << messages.first.raw_payload

    # Trigger rebalance after certain number of messages
    if DT[:processed].size >= 6 && DT[:rebalanced].empty? && DT[:trigger_rebalance].empty?
      DT[:trigger_rebalance] << true
    end
  end

  def revoked
    DT[:revoked_called] << topic.name
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key }
    )
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

# Create deterministic test messages for each segment
segment_messages = { 0 => [], 1 => [], 2 => [] }

# Create messages for each segment with deterministic keys
[0, 1, 2].each do |segment_id|
  5.times do |i|
    # Find a key that maps to this segment
    key = nil
    (0..100).each do |j|
      candidate = "key-seg#{segment_id}-#{i}-#{j}"
      if candidate.to_s.sum % 3 == segment_id
        key = candidate
        break
      end
    end

    segment_messages[segment_id] << {
      topic: DT.topic,
      key: key,
      payload: "payload-#{segment_id}-#{i}"
    }
  end
end

# Store expected segment assignments
expected_assignments = {}
segment_messages.each do |segment_id, messages|
  messages.each do |message|
    expected_assignments[message[:key]] = segment_id
  end
end

# Producer thread that will send messages in phases
producer_thread = Thread.new do
  # Phase 1: Initial messages
  initial_batch = []

  segment_messages.each do |_segment_id, messages|
    initial_batch.concat(messages.first(3))
  end

  Karafka::App.producer.produce_many_sync(initial_batch)

  # Wait for trigger to rebalance
  loop do
    break unless DT[:trigger_rebalance].empty?

    sleep(0.5)
  end

  # Create a new consumer to trigger rebalance
  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  # Poll a few times to trigger rebalance
  5.times do
    consumer.poll(1000)
    sleep(0.5)
  end

  # Mark that rebalance has been triggered
  DT[:rebalanced] << true

  # Phase 2: Post-rebalance messages
  sleep(2) # Give time for rebalance to complete

  second_batch = []
  segment_messages.each do |_segment_id, messages|
    second_batch.concat(messages.last(2))
  end

  Karafka::App.producer.produce_many_sync(second_batch)

  # Close the consumer
  consumer.close

  # Mark producer thread as done
  DT[:producer_done] << true
end

# Start Karafka and wait for everything to complete
start_karafka_and_wait_until do
  # Wait until producer is done and we've processed enough messages
  # OR we've detected revocation
  !DT[:producer_done].empty? &&
    (DT[:processed].size >= 12 || !DT[:revoked_events].empty? || !DT[:revoked_called].empty?)
end

# Ensure producer thread is cleaned up
producer_thread.join

# Group processed messages by pre-rebalance and post-rebalance
pre_rebalance = DT[:processed].select { |p| p[:before_rebalance] }
post_rebalance = DT[:processed].reject { |p| p[:before_rebalance] }

# 1. Verify pre-rebalance assignments match expected assignments
pre_rebalance.each do |record|
  key = record[:key]
  segment_id = record[:segment_id]
  expected_segment = expected_assignments[key]

  assert_equal(
    expected_segment,
    segment_id,
    "Key #{key} was assigned to segment #{segment_id} but should be segment #{expected_segment}"
  )
end

# 2. Verify post-rebalance assignments match expected assignments
post_rebalance.each do |record|
  key = record[:key]
  segment_id = record[:segment_id]
  expected_segment = expected_assignments[key]

  assert_equal(
    expected_segment,
    segment_id,
    "Key #{key} was assigned to segment #{segment_id} but should be segment #{expected_segment}"
  )
end

# 3. Verify consistent assignment across rebalance for any keys processed both before and after
processed_in_both_phases = pre_rebalance.map { |p| p[:key] } & post_rebalance.map { |p| p[:key] }

processed_in_both_phases.each do |key|
  pre_segment = pre_rebalance.find { |p| p[:key] == key }[:segment_id]
  post_segment = post_rebalance.find { |p| p[:key] == key }[:segment_id]

  assert_equal(
    pre_segment,
    post_segment,
    "Assignment after rebalance: Key #{key} moved from segment #{pre_segment} to #{post_segment}"
  )
end

# 4. Verify revocation was triggered (either through the callback or notification)
revocation_detected = !DT[:revoked_called].empty? || !DT[:revoked_events].empty?

# The logs show revocation happening, so this should pass with either method
assert(
  revocation_detected,
  'Revocation was not detected during the test.' \
  " Revoked called: #{DT[:revoked_called].inspect}, Revoked events: #{DT[:revoked_events].inspect}"
)

# 5. Check that each segment processed some messages
[0, 1, 2].each do |segment_id|
  segment_processed = DT[:processed].select { |p| p[:segment_id] == segment_id }

  assert(
    !segment_processed.empty?,
    "Segment #{segment_id} didn't process any messages"
  )
end

# 6. Check that offsets were committed for each segment
segment0_group_id = "#{DT.consumer_group}-parallel-0"
segment1_group_id = "#{DT.consumer_group}-parallel-1"
segment2_group_id = "#{DT.consumer_group}-parallel-2"

segment0_offset = fetch_next_offset(DT.topic, consumer_group_id: segment0_group_id)
segment1_offset = fetch_next_offset(DT.topic, consumer_group_id: segment1_group_id)
segment2_offset = fetch_next_offset(DT.topic, consumer_group_id: segment2_group_id)

# At least one segment should have committed offsets
committed_segments = [
  { id: 0, offset: segment0_offset },
  { id: 1, offset: segment1_offset },
  { id: 2, offset: segment2_offset }
].select { |s| s[:offset] > 0 }

assert(
  !committed_segments.empty?,
  "No segments committed any offsets: #{[segment0_offset, segment1_offset, segment2_offset]}"
)

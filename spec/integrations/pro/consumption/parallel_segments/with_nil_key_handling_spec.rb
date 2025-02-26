# frozen_string_literal: true
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.
# Messages with nil keys should be handled gracefully and assigned to a consistent group

setup_karafka do |config|
  config.concurrency = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id

    messages.each do |message|
      key_info = message.key.nil? ? 'nil_key' : message.key
      DT[:key_assignments] << [key_info, segment_id]

      if message.raw_payload.start_with?('nil-key')
        DT[:batch] << ['first', key_info, segment_id]
      elsif message.raw_payload.start_with?('second-batch')
        DT[:batch] << ['second', key_info, segment_id]
      end

      DT[segment_id] << message.raw_payload
    end
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
    end
  end
end

nil_key_messages = []
regular_messages = []

20.times do |i|
  nil_key_messages << {
    topic: DT.topic,
    key: nil,
    payload: "nil-key-payload-#{i}"
  }
end

30.times do |i|
  regular_messages << {
    topic: DT.topic,
    key: "key-#{i}",
    payload: "regular-payload-#{i}"
  }
end

second_batch_nil_keys = []
10.times do |i|
  second_batch_nil_keys << {
    topic: DT.topic,
    key: nil,
    payload: "second-batch-nil-key-#{i}"
  }
end

first_batch_nil_payloads = nil_key_messages.map { |m| m[:payload] }
second_batch_nil_payloads = second_batch_nil_keys.map { |m| m[:payload] }

producer_thread = Thread.new do
  sleep(1) until DT[:key_assignments].count { |key, _| key == 'nil_key' } >= 20

  Karafka::App.producer.produce_many_sync(second_batch_nil_keys)
end

all_messages = nil_key_messages + regular_messages
Karafka::App.producer.produce_many_sync(all_messages)

start_karafka_and_wait_until do
  if producer_thread.alive? && DT[:key_assignments].count { |key, _| key == 'nil_key' } >= 20
    producer_thread.join
  end

  DT[:key_assignments].count { |key, _| key == 'nil_key' } >= 30
end

nil_key_assignments = DT[:key_assignments].select { |key, _| key == 'nil_key' }
nil_key_segments = nil_key_assignments.map { |_, segment| segment }.uniq

assert_equal(
  1,
  nil_key_segments.size,
  "Nil key messages were assigned to multiple segments: #{nil_key_segments}"
)

# Determine which segment received the nil key messages
nil_key_segment = nil_key_segments.first

# Verify all nil key messages from first batch were processed
first_batch_processed = DT[nil_key_segment].select { |p| p.start_with?('nil-key') }
assert_equal(
  first_batch_nil_payloads.sort,
  first_batch_processed.sort,
  'Not all first batch nil key messages were processed'
)

# Verify all nil key messages from second batch were processed by the same segment
second_batch_processed = DT[nil_key_segment].select { |p| p.start_with?('second-batch') }
assert_equal(
  second_batch_nil_payloads.sort,
  second_batch_processed.sort,
  'Not all second batch nil key messages were processed'
)

# Verify other segments didn't process nil key messages
other_segments = [0, 1, 2] - [nil_key_segment]
other_segments.each do |segment|
  nil_key_in_segment = DT[segment].any? do |p|
    p.start_with?('nil-key', 'second-batch')
  end

  assert !nil_key_in_segment, "Segment #{segment} incorrectly processed nil key messages"
end

# Finally, verify the reducer logic is deterministic for nil keys
expected_nil_segment = nil.to_s.sum % 3
assert_equal(
  expected_nil_segment,
  nil_key_segment,
  "Nil keys didn't go to the expected segment based on the nil.to_s.sum % count formula"
)

# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When there are messages for dispatch but they were already dispatched (tombstone exists),
# we should not dispatch them again. We should only dispatch the once that were not

setup_karafka

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    active(false)
  end
end

def build_message(id)
  {
    topic: DT.topics[1],
    key: "key-#{id}",
    headers: { 'id' => id },
    payload: "payload-#{id}",
    partition: 0
  }
end

def build_tombstone(id)
  {
    topic: DT.topics[0],
    key: "key-#{id}",
    payload: nil,
    headers: {
      'schedule_source_type' => 'tombstone',
      'schedule_schema_version' => '1.0.0'
    }
  }
end

old_messages = Array.new(10) do |i|
  build_message(i.to_s)
end

new_messages = [build_message('101')]

tombstones = Array.new(10) do |i|
  build_tombstone(i.to_s)
end

old_proxies = old_messages.map do |message|
  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i,
    envelope: {
      topic: DT.topics[0],
      key: message[:key]
    }
  )
end

new_proxies = new_messages.map.with_index do |message, i|
  Karafka::Pro::ScheduledMessages.schedule(
    message: message,
    epoch: Time.now.to_i + i + 2,
    envelope: {
      topic: DT.topics[0],
      key: message[:key]
    }
  )
end

# We force dispatch to past to simulate old messages
old_proxies.each do |proxy|
  proxy[:headers]['schedule_target_epoch'] = (Time.now.to_i - 600).to_s
end

Karafka.producer.produce_many_sync(old_proxies)
Karafka.producer.produce_many_sync(new_proxies)
Karafka.producer.produce_many_sync(tombstones)

dispatched = nil

start_karafka_and_wait_until(sleep: 1) do
  dispatched = Karafka::Admin.read_topic(DT.topics[1], 0, 100).first
end

# Only this message should be available
assert_equal dispatched.raw_key, 'key-101'
assert_equal dispatched.raw_payload, 'payload-101'
assert_equal dispatched.partition, 0

headers = dispatched.raw_headers

assert_equal headers['id'], '101'
assert_equal headers['schedule_schema_version'], '1.0.0'
assert headers.key?('schedule_target_epoch')
assert_equal headers['schedule_source_type'], 'schedule'
assert_equal headers['schedule_target_topic'], DT.topics[1]
assert_equal headers['schedule_target_partition'], '0'
assert_equal headers['schedule_target_key'], 'key-101'
assert_equal headers['schedule_source_topic'], DT.topic

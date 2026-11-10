# frozen_string_literal: true

# Karafka::Admin.copy_dead_letter_queue should copy only the requested partitions and offset
# range, keeping keys and headers and incrementing an existing replay count header.

setup_karafka

Karafka::Admin.create_topic(DT.topics[0], 2, 1)
Karafka::Admin.create_topic(DT.topics[1], 1, 1)

Karafka.producer.produce_many_sync(
  Array.new(10) do |i|
    {
      topic: DT.topics[0],
      partition: 1,
      payload: i.to_s,
      key: "key#{i}",
      headers: { "user" => "value", "replay_count" => "1" }
    }
  end
)

Karafka.producer.produce_sync(topic: DT.topics[0], partition: 0, payload: "other")

copied = Karafka::Admin.copy_dead_letter_queue(
  DT.topics[0],
  target_topic_name: DT.topics[1],
  partitions: [1],
  start_offset: 3,
  end_offset: 6
)

assert_equal 3, copied

replayed = Karafka::Admin.read_topic(DT.topics[1], 0, 10, 0)

assert_equal %w[3 4 5], replayed.map(&:raw_payload)
assert_equal %w[key3 key4 key5], replayed.map(&:raw_key)
assert_equal [{ "user" => "value", "replay_count" => "2" }], replayed.map(&:raw_headers).uniq

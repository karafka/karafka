# frozen_string_literal: true

# Karafka::Admin.delete_records should delete the messages below the given offset, keep the rest
# and move the low watermark to that offset.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

Karafka.producer.produce_many_sync(Array.new(10) { |i| { topic: DT.topic, payload: i.to_s } })

result = Karafka::Admin.delete_records({ DT.topic => [{ partition: 0, offset: 4 }] })

assert_equal [{ topic: DT.topic, partition: 0, offset: 4 }], result
assert_equal [4, 10], Karafka::Admin.read_watermark_offsets(DT.topic, 0)

messages = Karafka::Admin.read_topic(DT.topic, 0, 10, 0)

assert_equal (4..9).to_a, messages.map(&:offset)
assert_equal (4..9).map(&:to_s), messages.map(&:raw_payload)

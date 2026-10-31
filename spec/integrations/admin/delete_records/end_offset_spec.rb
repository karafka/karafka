# frozen_string_literal: true

# Karafka::Admin.delete_records with `:end` should delete all the messages in the partition and
# leave the other partitions untouched.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 2, 1)

5.times { |i| Karafka.producer.produce_sync(topic: DT.topic, payload: i.to_s, partition: 0) }
3.times { |i| Karafka.producer.produce_sync(topic: DT.topic, payload: i.to_s, partition: 1) }

result = Karafka::Admin.delete_records({ DT.topic => [{ partition: 0, offset: :end }] })

assert_equal [{ topic: DT.topic, partition: 0, offset: 5 }], result
assert_equal [5, 5], Karafka::Admin.read_watermark_offsets(DT.topic, 0)
assert_equal [], Karafka::Admin.read_topic(DT.topic, 0, 10, 0)
assert_equal [0, 3], Karafka::Admin.read_watermark_offsets(DT.topic, 1)
assert_equal 3, Karafka::Admin.read_topic(DT.topic, 1, 10, 0).size

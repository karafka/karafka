# frozen_string_literal: true

# Karafka::Admin.delete_records with an offset above the high watermark should raise and delete
# nothing.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 1, 1)

Karafka.producer.produce_many_sync(Array.new(5) { |i| { topic: DT.topic, payload: i.to_s } })

error = nil

begin
  Karafka::Admin.delete_records({ DT.topic => [{ partition: 0, offset: 100 }] })
rescue Rdkafka::RdkafkaTopicPartitionListError => e
  error = e
end

assert_equal :offset_out_of_range, error.code
assert_equal [0, 5], Karafka::Admin.read_watermark_offsets(DT.topic, 0)
assert_equal 5, Karafka::Admin.read_topic(DT.topic, 0, 10, 0).size

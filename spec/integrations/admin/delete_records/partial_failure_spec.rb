# frozen_string_literal: true

# Karafka::Admin.delete_records with one partition failing should still delete from the other
# partitions and raise an error that names the failed partition and carries every result.

setup_karafka

Karafka::Admin.create_topic(DT.topic, 2, 1)

5.times { |i| Karafka.producer.produce_sync(topic: DT.topic, payload: i.to_s, partition: 0) }
5.times { |i| Karafka.producer.produce_sync(topic: DT.topic, payload: i.to_s, partition: 1) }

error = nil

begin
  Karafka::Admin.delete_records(
    { DT.topic => [{ partition: 0, offset: 3 }, { partition: 1, offset: 100 }] }
  )
rescue Rdkafka::RdkafkaTopicPartitionListError => e
  error = e
end

assert_equal :offset_out_of_range, error.code
assert error.message.include?("partition 1 of '#{DT.topic}'")

results = error.topic_partition_list.to_h.fetch(DT.topic).to_h { |p| [p.partition, p] }

assert_equal 0, results[0].err
assert_equal 3, results[0].offset
assert_not_equal 0, results[1].err

assert_equal [3, 5], Karafka::Admin.read_watermark_offsets(DT.topic, 0)
assert_equal [0, 5], Karafka::Admin.read_watermark_offsets(DT.topic, 1)

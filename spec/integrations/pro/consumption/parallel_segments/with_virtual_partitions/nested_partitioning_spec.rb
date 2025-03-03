# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Virtual partitions should correctly subdivide workloads within parallel segment groups

setup_karafka do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    segment_id = topic.consumer_group.segment_id
    batch_id = SecureRandom.hex(4)
    processing_thread = Thread.current.object_id

    DT[:batches] << {
      segment_id: segment_id,
      batch_id: batch_id,
      thread_id: processing_thread,
      time: Time.now.to_f,
      messages: messages.count,
      vp_keys: messages.map { |m| extract_vp_key(m) }.uniq
    }

    sleep(5)

    messages.each do |message|
      vp_key = extract_vp_key(message)

      DT[:processed] << {
        key: message.key,
        segment_id: segment_id,
        batch_id: batch_id,
        thread_id: processing_thread,
        vp_key: vp_key
      }

      DT[segment_id] << message.raw_payload
      DT["segment-#{segment_id}-vpkey-#{vp_key}"] << message.raw_payload
    end
  end

  private

  def extract_vp_key(message)
    message.raw_payload.split('-').first
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    parallel_segments(
      count: 3,
      partitioner: ->(message) { message.raw_key.split('-').first }
    )

    topic DT.topic do
      consumer Consumer

      virtual_partitions(
        partitioner: ->(message) { message.raw_payload.split('-').first },
        max_partitions: 4
      )
    end
  end
end

messages = []

3.times do |sg|
  4.times do |vp|
    10.times do |i|
      segment_key = "sg#{sg}"
      vp_key = "vp#{vp}"

      messages << {
        topic: DT.topic,
        key: "#{segment_key}-msg-#{i}",
        payload: "#{vp_key}-data-#{i}"
      }
    end
  end
end

messages.shuffle!

Karafka::App.producer.produce_many_sync(messages)

start_karafka_and_wait_until do
  DT[:processed].size >= 120
end

# 1. Group by parallel segment
by_segment = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  by_segment[segment_id] ||= []
  by_segment[segment_id] << record
end

# 2. Within each segment, group by batch/thread
by_segment_and_batch = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  batch_id = record[:batch_id]

  by_segment_and_batch[segment_id] ||= {}
  by_segment_and_batch[segment_id][batch_id] ||= []
  by_segment_and_batch[segment_id][batch_id] << record
end

# 3. Check that each segment received its messages
segment_keys = (0..2).map { |sg| "sg#{sg}" }
segment_keys.each do |sg_key|
  records = DT[:processed].select { |r| r[:key].start_with?("#{sg_key}-") }

  segment_ids = records.map { |r| r[:segment_id] }.uniq
  assert_equal(
    1,
    segment_ids.size,
    "Messages for segment key #{sg_key} should go to the same segment, found in: #{segment_ids}"
  )

  assert_equal(
    40,
    records.size,
    "Segment key #{sg_key} should have 40 messages (10 msgs × 4 VPs)"
  )
end

# 4. Check that each segment created multiple batches/threads for virtual partitions
by_segment.each do |segment_id, records|
  batch_ids = records.map { |r| r[:batch_id] }.uniq

  assert(
    batch_ids.size > 1,
    "Segment #{segment_id} should create multiple batches for vps, found #{batch_ids.size}"
  )
end

# 5. Check VP key distribution within batches
vp_key_batch_distribution = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  vp_key = record[:vp_key]
  batch_id = record[:batch_id]

  vp_key_batch_distribution[segment_id] ||= {}
  vp_key_batch_distribution[segment_id][vp_key] ||= Set.new
  vp_key_batch_distribution[segment_id][vp_key] << batch_id
end

vp_key_batch_distribution.each do |segment_id, vp_distribution|
  vp_distribution.each do |vp_key, batch_ids|
    message_count = DT[:processed].count do |r|
      r[:segment_id] == segment_id && r[:vp_key] == vp_key
    end

    assert(
      batch_ids.size < message_count,
      "VP key #{vp_key} in segment #{segment_id} was distributed across too many batches: "\
      "#{batch_ids.size} batches for #{message_count} messages"
    )
  end
end

# 6. Check thread utilization
threads_by_segment = {}
DT[:processed].each do |record|
  segment_id = record[:segment_id]
  thread_id = record[:thread_id]

  threads_by_segment[segment_id] ||= Set.new
  threads_by_segment[segment_id] << thread_id
end

threads_by_segment.each do |segment_id, threads|
  assert(
    threads.size > 1,
    "Segment #{segment_id} should use multiple threads for vps, used #{threads.size}"
  )
end

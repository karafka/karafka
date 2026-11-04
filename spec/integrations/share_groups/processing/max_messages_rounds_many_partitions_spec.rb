# frozen_string_literal: true

# Share group (KIP-932) poll batches spanning several partitions are consumed in rounds of at most
# `max_messages` records per partition: each batch has records of one partition only, rounds of
# the same partition never overlap while different partitions are processed in parallel.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    started_at = Time.now.to_f
    sleep(0.2)

    DT[:batches] << {
      size: messages.size,
      partition: messages.metadata.partition,
      partitions: messages.map(&:partition).uniq,
      started_at: started_at,
      finished_at: Time.now.to_f
    }

    messages.each do |message|
      DT[:accepted] << message.raw_payload
      mark_as_accepted(message)
    end
  end
end

draw_routes(create_topics: false) do
  share_group DT.group do
    topic DT.topic do
      max_messages 3
      # Allow a single poll to acquire more records than one consume gets
      kafka(
        "bootstrap.servers": "127.0.0.1:9092",
        "max.poll.records": 100,
        "statistics.interval.ms": 100
      )
      consumer Consumer
    end
  end
end

setup_share_group(DT.topic, DT.group, 3)

elements = []

3.times do |partition|
  payloads = DT.uuids(10)
  elements += payloads
  produce_many(DT.topic, payloads, partition: partition)
end

start_karafka_and_wait_until do
  DT[:accepted].uniq.size >= 30
end

assert_equal elements.sort, DT[:accepted].uniq.sort

DT[:batches].each do |batch|
  assert batch[:size] <= 3
  assert_equal [batch[:partition]], batch[:partitions]
end

# At least 4 rounds per partition were needed for 10 records each
assert DT[:batches].size >= 12

overlap = lambda do |first, second|
  first[:started_at] < second[:finished_at] && second[:started_at] < first[:finished_at]
end

DT[:batches].group_by { |batch| batch[:partition] }.each_value do |batches|
  batches.combination(2).each do |first, second|
    assert !overlap.call(first, second)
  end
end

parallel = DT[:batches].combination(2).any? do |first, second|
  first[:partition] != second[:partition] && overlap.call(first, second)
end

assert parallel

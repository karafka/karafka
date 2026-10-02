# frozen_string_literal: true

# Share group (KIP-932) records are processed per topic partition, like with consumer groups: a
# poll batch spanning several partitions is split into one job per partition and those jobs run in
# parallel on different workers. Each batch reports the real partition of its records.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    started_at = Time.now.to_f
    sleep(1)

    DT[:batches] << {
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

# Every batch belongs to exactly one partition and reports it in its metadata
DT[:batches].each do |batch|
  assert_equal [batch[:partition]], batch[:partitions]
end

# Batches of different partitions were processed at the same time
overlapping = DT[:batches].combination(2).any? do |first, second|
  first[:partition] != second[:partition] &&
    first[:started_at] < second[:finished_at] &&
    second[:started_at] < first[:finished_at]
end

assert overlapping

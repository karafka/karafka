# frozen_string_literal: true

# When a second consumer joins with an eager assignment strategy while Karafka has many messages
# already prefetched, every message should be consumed at least once, with no offset gaps per
# partition and no duplicates within one run of a given owner.
#
# Small partition fetches and slow batches keep the librdkafka queue full, so the batches are
# mostly drained.

PARTITIONS = 4
PER_PARTITION = 2_000

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 200
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.kafka[:"partition.assignment.strategy"] = "range,roundrobin"
end

class Consumer < Karafka::BaseConsumer
  def consume
    sleep(0.5)

    messages.each do |message|
      return unless mark_as_consumed!(message)

      DT[:runs][[partition, object_id]] << message.offset
      DT[:all][partition] << message.offset
    end
  end
end

DT[:runs] = Hash.new { |h, k| h[k] = [] }
DT[:all] = Hash.new { |h, k| h[k] = [] }
DT[:other] = Hash.new { |h, k| h[k] = [] }

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

other = Thread.new do
  sleep(0.1) until DT[:all].values.sum(&:size) >= 200

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)

  taken = 0
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30

  while taken < 200 && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    message = consumer.poll(100)

    next unless message

    DT[:other][message.partition] << message.offset
    consumer.store_offset(message)
    taken += 1
  end

  consumer.commit(nil, false) if taken.positive?
  consumer.close

  DT[:other_done] = true
end

# A lost message would make us wait forever, so we stop and let the assertions fail
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90

start_karafka_and_wait_until do
  next true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

  DT.key?(:other_done) &&
    PARTITIONS.times.all? do |partition|
      (DT[:all][partition] + DT[:other][partition]).uniq.size >= PER_PARTITION
    end
end

other.join

# The second consumer really took some partitions over
assert DT[:other].values.sum(&:size).positive?

PARTITIONS.times do |partition|
  assert_equal(
    (0...PER_PARTITION).to_a,
    (DT[:all][partition] + DT[:other][partition]).uniq.sort
  )
end

# The wait condition above creates empty lists for partitions the second consumer did not get
(DT[:runs].values + DT[:other].values).reject(&:empty?).each do |offsets|
  assert_equal (offsets.first..offsets.last).to_a, offsets
end

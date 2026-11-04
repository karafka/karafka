# frozen_string_literal: true

# Share group (KIP-932) batches expose metadata matching their records (topic, real partition,
# size, first and last offset) and each message carries its delivery count, partition, offset, key
# and headers.

setup_karafka

class Consumer < Karafka::ShareConsumer
  def consume
    metadata = messages.metadata

    DT[:batches] << {
      topic: metadata.topic,
      partition: metadata.partition,
      size: metadata.size,
      first_offset: metadata.first_offset,
      last_offset: metadata.last_offset,
      messages_topics: messages.map(&:topic).uniq,
      messages_partitions: messages.map(&:partition).uniq,
      count: messages.size,
      offsets: messages.map(&:offset)
    }

    messages.each do |message|
      DT[:messages] << {
        payload: message.raw_payload,
        partition: message.partition,
        offset: message.offset,
        key: message.key,
        headers: message.headers,
        delivery_count: message.delivery_count
      }

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

setup_share_group(DT.topic, DT.group, 2)

expected = {}

2.times do |partition|
  5.times do |index|
    payload = "#{partition}-#{index}"
    expected[payload] = partition

    produce(
      DT.topic,
      payload,
      partition: partition,
      key: "key-#{payload}",
      headers: { "partition" => partition.to_s, "index" => index.to_s }
    )
  end
end

start_karafka_and_wait_until do
  DT[:messages].map { |message| message[:payload] }.uniq.size >= 10
end

DT[:batches].each do |batch|
  assert_equal DT.topic, batch[:topic]
  assert_equal [DT.topic], batch[:messages_topics]
  assert_equal [batch[:partition]], batch[:messages_partitions]
  assert_equal batch[:count], batch[:size]
  assert_equal batch[:offsets].first, batch[:first_offset]
  assert_equal batch[:offsets].last, batch[:last_offset]
end

assert_equal [0, 1], DT[:batches].map { |batch| batch[:partition] }.uniq.sort

DT[:messages].each do |message|
  partition, index = message[:payload].split("-")

  assert_equal expected.fetch(message[:payload]), message[:partition]
  assert_equal index.to_i, message[:offset]
  assert_equal "key-#{message[:payload]}", message[:key]
  assert_equal({ "partition" => partition, "index" => index }, message[:headers])
  assert_equal 1, message[:delivery_count]
end

# frozen_string_literal: true

# With `internal.connection.batch_polling` off, Karafka should poll already fetched messages one
# at a time and never call `poll_batch_nb`. This is the fall back
# for users that hit a problem with the drain, so it must keep consumption complete.
#
# Small partition fetches and a slow first batch make librdkafka queue messages of all the
# partitions that a drain would normally take.

PARTITIONS = 4
PER_PARTITION = 100

setup_karafka do |config|
  config.kafka[:"max.partition.fetch.bytes"] = 1_024
  config.max_messages = 50
  config.concurrency = 4
  config.internal.connection.batch_polling = false
end

track_drains

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[partition] << message.offset }
  end
end

draw_topics do
  topic DT.topic do
    partitions PARTITIONS
  end
end

draw_routes(create_topics: false) do
  topic DT.topic do
    consumer Consumer
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

start_karafka_and_wait_until do
  PARTITIONS.times.all? { |partition| DT[partition].size >= PER_PARTITION }
end

assert_equal false, Karafka::App.config.internal.connection.batch_polling
assert DT[:drains].empty?

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[partition]
end

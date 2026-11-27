# frozen_string_literal: true

# With `internal.connection.batch_polling` off and `enable.partition.eof` on, eof events of many
# partitions come one per blocking poll. Every partition at its end should
# still get `eofed`, and `poll_batch_nb` should never be called.
#
# A slow first batch makes librdkafka queue the messages and eof events of all the partitions.

PARTITIONS = 10
PER_PARTITION = 10

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 15
  config.concurrency = 5
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

    DT[:eofs] << partition if eofed?
  end

  def eofed
    DT[:eofs] << partition
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
    eofed true
  end
end

PARTITIONS.times do |partition|
  produce_many(DT.topic, DT.uuids(PER_PARTITION), partition: partition)
end

start_karafka_and_wait_until do
  DT[:eofs].uniq.size >= PARTITIONS
end

assert DT[:drains].empty?
assert_equal (0...PARTITIONS).to_a, DT[:eofs].uniq.sort

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[partition]
end

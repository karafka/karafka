# frozen_string_literal: true

# When the drain fills the buffer up to `max_messages`, the eof events of the partitions that did
# not fit should arrive in the next batches. No batch should go over `max_messages`, and no eof and
# no message should be lost.
#
# A slow first batch makes librdkafka queue messages and eof events of many partitions, much more
# than fits into one batch, with each eof right after the messages of its partition.

PARTITIONS = 10
PER_PARTITION = 10

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 15
end

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do |event|
  DT[:sizes] << event[:messages_buffer].size
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:slowed)
      DT[:slowed] = true
      sleep(5)
    end

    messages.each { |message| DT[partition] << message.offset }

    eofed if eofed?
  end

  def eofed
    return unless DT[partition].size >= PER_PARTITION

    DT[:eofed] << partition
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

consumed_at = nil

start_karafka_and_wait_until do
  done = (0...PARTITIONS).all? { |partition| DT[partition].size >= PER_PARTITION }
  consumed_at ||= Time.now if done

  # Give the eof events time to arrive once everything is consumed, but do not wait forever when
  # one got lost
  DT[:eofed].uniq.size >= PARTITIONS || (consumed_at && Time.now - consumed_at > 20)
end

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[partition]
end

assert_equal (0...PARTITIONS).to_a, DT[:eofed].uniq.sort
assert DT[:sizes].max <= 15

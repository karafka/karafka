# frozen_string_literal: true

# When eof events of many partitions are taken in one go after the first poll, some of them can
# come after all the messages of their partitions were already consumed in an earlier batch. Those
# partitions have no messages left and only `#eofed` jobs run for them. Every partition should get
# its eof, either with its last messages (`#eofed?` in `#consume`) or in an `#eofed` job, and
# messages should be consumed once and in order.
#
# A slow first batch makes librdkafka queue the messages and eof events of all the partitions. The
# `max_messages` limit cuts batches between messages and their eof events.

PARTITIONS = 10
PER_PARTITION = 10

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 15
  config.concurrency = 5
end

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do
  DT[:polls] << true
end

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
    DT[:eofed_only] << DT[:polls].size
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
  DT[:eofs].uniq.size >= PARTITIONS || (consumed_at && Time.now - consumed_at > 20)
end

PARTITIONS.times do |partition|
  assert_equal (0...PER_PARTITION).to_a, DT[partition]
end

assert_equal (0...PARTITIONS).to_a, DT[:eofs].uniq.sort
assert DT[:eofed_only].any?

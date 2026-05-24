# frozen_string_literal: true

# When enable.partition.eof is true and a topic has 5 partitions, producing messages to each
# partition and then consuming until EOF should trigger the eofed callback for ALL 5 partitions.
# This is a regression test for a bug where EOF events delivered inline with the last batch of
# messages were dropped in an ensure-block cleanup path, causing some partitions to never
# receive their eofed callback.

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.max_messages = 100
  config.max_wait_time = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.partition
    end
  end

  def eofed
    DT[:eofed] << partition
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    config(partitions: 5)
    eofed true
  end
end

5.times do |i|
  produce_many(DT.topic, DT.uuids(20), partition: i)
end

start_karafka_and_wait_until do
  DT[:eofed].uniq.size >= 5
end

assert_equal [0, 1, 2, 3, 4], DT[:eofed].uniq.sort
assert_equal 100, DT[:messages].size

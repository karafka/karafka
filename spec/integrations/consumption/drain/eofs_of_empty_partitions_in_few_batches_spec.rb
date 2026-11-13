# frozen_string_literal: true

# When many empty partitions reach their eof at assignment, the eof events after the first one
# should be drained into the same batch. Every partition should get its `#eofed` once, in far fewer
# batches than there are partitions, instead of one batch per eof.

PARTITIONS = 20

setup_karafka do |config|
  config.kafka[:"enable.partition.eof"] = true
  config.concurrency = 5
end

Karafka.monitor.subscribe("connection.listener.fetch_loop.received") do
  DT[:polls] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise
  end

  def eofed
    DT[:eofed] << partition
    DT[:batches] << DT[:polls].size
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

start_karafka_and_wait_until do
  DT[:eofed].size >= PARTITIONS
end

assert_equal (0...PARTITIONS).to_a, DT[:eofed].sort
assert DT[:batches].uniq.size <= PARTITIONS / 4, DT[:batches]

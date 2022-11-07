# frozen_string_literal: true

# A case where we have 10 workers consuming data from 10 partitions with simulated IO (sleep)
# Here we stream data in real-time (which works differently than catching up) and simulate IO
# by sleeping 1ms per message to benchmark parallel processing.

setup_karafka do |config|
  config.kafka[:'auto.offset.reset'] = 'latest'
  config.concurrency = 10
end

# How many messages we want to consume per partition before stop
MAX_MESSAGES_PER_PARTITION = 1_000

# How many partitions do we have
PARTITIONS_COUNT = 10

Process.fork_supervised do
  # Dispatch 1000 messages to each partition
  1_000.times do
    PARTITIONS_COUNT.times do |i|
      Karafka.producer.buffer(topic: 'benchmarks_00_10', payload: 'a', partition: i)
    end
  end

  Karafka.producer.flush_sync
end

# Benchmarked consumer
class Consumer < Karafka::BaseConsumer
  def initialize
    super
    $start ||= Time.monotonic
    @count = 0
  end

  # Benchmarked consumption
  def consume
    @count += messages.size

    # Assume each message persistence takes 1ms
    sleep(messages.count / 1_000.to_f)

    DT.data[:completed] << messages.metadata.partition if @count >= MAX_MESSAGES_PER_PARTITION

    return if DT.data[:completed].size != PARTITIONS_COUNT
    return if $stop

    $stop = Time.monotonic
    Thread.new { Karafka::Server.stop }
  end
end

draw_routes('benchmarks_00_10')

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DT.data[:completed] = Set.new
  $start = false
  $stop = false

  Karafka::Server.run

  $stop - $start
end

# Workers count (messages per second)
#  1: 967.0931828004976
#  2: 1846.9631336499262
#  3: 2627.037884455041
#  4: 3343.378212044422
#  5: 3733.2891955212363
#  6: 4313.176246527221
#  7: 4980.996950715934
#  8: 5577.77580393055
#  9: 5825.016430358137
# 10: 6255.494936614387
# 11: 6151.344610570285
# 12: 6117.579001175221
# 13: 6282.5906551290955
# 14: 6305.589790322177
# 15: 6146.980026710657

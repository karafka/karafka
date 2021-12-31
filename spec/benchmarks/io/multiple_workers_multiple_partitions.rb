# frozen_string_literal: true

# A case where we have 5 workers consuming data from 10 partitions with simulated IO (sleep)
# Here we stream data in real-time (which works differently than catching up) and simulate IO
# by sleeping 1ms per message to benchmark parallel processing.

setup_karafka do |config|
  config.kafka['auto.offset.reset'] = 'latest'
  config.concurrency = 10
end

MAX_MESSAGES_PER_PARTITION = 1_000

PARTITIONS_COUNT = 10

Process.fork_supervised do
  1000.times do |iter|
    PARTITIONS_COUNT.times do |i|
      Karafka.producer.buffer(topic: 'benchmarks_0_10', payload: 'a', partition: i)
    end
  end

  Karafka.producer.flush_sync
end

class Consumer < Karafka::BaseConsumer
  def initialize
    $start ||= Time.monotonic
    @count = 0
  end

  def consume
    @count += messages.size

    # Assume each message persistence takes 1ms
    sleep(messages.count / 1_000.to_f)

    #p [@count, messages.metadata.partition, DataCollector.data[:completed].size]

    if @count >= MAX_MESSAGES_PER_PARTITION
      DataCollector.data[:completed] << messages.metadata.partition
    end

    if DataCollector.data[:completed].size == PARTITIONS_COUNT && !$stop
      $stop = Time.monotonic
      Thread.new { Karafka::Server.stop }
    end
  end
end

draw_routes('benchmarks_0_10')

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DataCollector.data[:completed] = Set.new
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

# frozen_string_literal: true

# A case where we have 10 workers consuming data from 10 partitions with simulated IO (sleep)
# Here we stream data in real-time (which works differently than catching up) and simulate IO
# by sleeping 1ms per message to benchmark parallel processing.

setup_karafka do |config|
  config.kafka[:"auto.offset.reset"] = "latest"
  config.concurrency = ENV.fetch("CONCURRENCY", 10).to_i
end

# How many messages we want to consume per partition before stop
MAX_MESSAGES_PER_PARTITION = 1_000

# How many partitions do we have
PARTITIONS_COUNT = 10

Process.fork_supervised do
  # Dispatch 1000 messages to each partition
  1_000.times do
    PARTITIONS_COUNT.times do |i|
      Karafka.producer.buffer(topic: "benchmarks_00_10", payload: "a", partition: i)
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

draw_routes("benchmarks_00_10")

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DT.data[:completed] = Set.new
  $start = false
  $stop = false

  reset_karafka_state!
  Karafka::Server.run

  $stop - $start
end

# Workers count (messages per second)
#  1: 934.096077883839311
#  2: 1930.138022722800614
#  3: 2502.432224018435407
#  4: 3296.080593324453945
#  5: 4100.778161970138729
#  6: 4154.084372545369577
#  7: 4876.209472176644790
#  8: 4416.402645019705111
#  9: 5643.081301914965298
# 10: 7206.639578508224654
# 11: 7354.674565237919734
# 12: 7527.780781931437848
# 13: 7507.761164811440552
# 14: 6957.094122640991776
# 15: 7323.753857415998806

# frozen_string_literal: true

# A case where we have 5 workers consuming data from 5 partitions with simulated IO (sleep)
# Here we stream data in real-time (which works differently than catching up) and simulate IO
# by sleeping 1ms per message to benchmark parallel processing.

become_pro!

setup_karafka do |config|
  config.kafka[:'auto.offset.reset'] = 'latest'
  config.concurrency = ENV.fetch('THREADS', 5).to_i
  config.license.token = pro_license_token
end

# How many messages we want to consume per partition before stop
MAX_MESSAGES_PER_PARTITION = 5_000

# How many partitions do we have
PARTITIONS_COUNT = 5

Process.fork_supervised do
  # Dispatch 1000 messages to each partition
  1_000.times do
    PARTITIONS_COUNT.times do |i|
      Karafka.producer.buffer(topic: 'benchmarks_01_05', payload: rand.to_s, partition: i)
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
    messages.each { sleep(0.001) }

    DT.data[:completed] << messages.count

    return if DT.data[:completed].sum < MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT
    return if $stop

    $stop = Time.monotonic

    Thread.new { Karafka::Server.stop }
  end
end

Karafka::App.routes.draw do
  consumer_group DT.consumer_group do
    topic 'benchmarks_01_05' do
      max_messages 1_000
      max_wait_time 1_000
      consumer Consumer
      virtual_partitions(
        partitioner: ->(msg) { msg.raw_payload }
      )
    end
  end
end

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DT.data[:completed] = []
  $start = false
  $stop = false

  reset_karafka_state!
  Karafka::Server.run

  $stop - $start
end

# Workers count (messages per second) without virtual partitions
#  1: 931.892318074926
#  2: 1599.6808223750108
#  3: 2318.8679906090706
#  4: 2536.64211469399
#  5: 4176.260605047068
#  6: 3971.138061398187
#  7: 4094.0693549677662
#  8: 4031.433044090448
#  9: 3749.0160056467316
# 10: 4100.561526498387
# 11: 4047.87674587464
# 12: 4087.8116991832862
# 13: 3748.521769090338
# 14: 3808.2463179935985
# 15: 3831.1358566813374

# Workers count (messages per second) with virtual partitions
#  1: 931.7357665956217
#  2: 1805.8756927157435
#  3: 2622.716709705871
#  4: 3414.644943780941
#  5: 4179.376542451191
#  6: 4896.035001589291
#  7: 5623.303828634968
#  8: 6314.4701807777965
#  9: 6948.446455077789
# 10: 7513.313427010764
# 11: 8248.405485337189
# 12: 8770.578580635449
# 13: 9385.023220702742
# 14: 9903.217718751765
# 15: 10370.618890828027

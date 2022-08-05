# frozen_string_literal: true

# A case where we have 5 workers consuming data from 5 partitions with simulated IO (sleep)
# Here we stream data in real-time (which works differently than catching up) and simulate IO
# by sleeping 1ms per message to benchmark parallel processing.

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
      manual_offset_management true
      virtual_partitioner ->(msg) { msg.raw_payload }
    end
  end
end

Tracker.run(messages_count: MAX_MESSAGES_PER_PARTITION * PARTITIONS_COUNT) do
  DT.data[:completed] = []
  $start = false
  $stop = false

  Karafka::Server.run

  $stop - $start
end

# Workers count (messages per second) without virtual partitions
#  1: 924.2120427393996
#  2: 1609.5505588983565
#  3: 2269.7284919624467
#  4: 2589.588361190777
#  5: 3673.3341758638744
#  6: 3650.416281687196
#  7: 3817.932566386849
#  8: 3719.580207595093
#  9: 3641.584374715836
# 10: 3722.6497657997056
# 11: 3607.4266962259353
# 12: 3819.1658231498723
# 13: 3684.8003910954517
# 14: 3681.1891516977953
# 15: 3715.6097518047077

# Workers count (messages per second) with virtual partitions
#  1: 922.6377049521686
#  2: 1687.7921877419155
#  3: 2531.3331193403137
#  4: 3220.700881087422
#  5: 3831.534849062132
#  6: 4443.214183799809
#  7: 4951.210308599216
#  8: 5357.536282511428
#  9: 5735.084475830164
# 10: 5897.795509304493
# 11: 6526.207526484219
# 12: 6581.75282597367
# 13: 6614.3426546697065
# 14: 6862.935718511713
# 15: 6731.095115013338

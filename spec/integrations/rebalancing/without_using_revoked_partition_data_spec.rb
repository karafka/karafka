# frozen_string_literal: true

# Karafka should not use data that was fetched partially for a partition that was lost
# in the same consumer instance that was revoked. There should be new instance created.
#
# New consumer instance should pick it up keeping continuity with the previous batch.
#
# When rebalance occurs and we're in the middle of data polling, data from a lost partition should
# be rejected as it is going to be picked up by a different process / instance.

# We simulate lost partition by starting a second consumer that will trigger a rebalance.

require 'securerandom'

RUN = SecureRandom.hex(6).split('-').first

setup_karafka do |config|
  config.max_wait_time = 20_000
  # Shutdown timeout should be bigger than the max wait as during shutdown we poll as well to be
  # able to finalize all work and not to loose the assignment
  # We need to set it that way in this particular spec so we do not force shutdown when we poll
  # during the shutdown phase
  config.shutdown_timeout = 80_000
  config.max_messages = 1_000
  config.initial_offset = 'latest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.data.key?(:revoked)

    messages.each do |message|
      DT[:process1] << message
    end
  end

  def revoked
    DT[:revoked] = messages.metadata.partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
  end
end

Thread.new do
  nr = 0

  loop do
    # If revoked, we are stopping, so producer will be closed
    break if DT.data.key?(:revoked)

    2.times do |i|
      produce(DT.topic, "#{RUN}-#{nr}-#{i}", partition: i)
    end

    nr += 1

    sleep(0.2)
  end
end

other = Thread.new do
  # We give it a bit of time, so we make sure we have something in the buffer
  sleep(30)

  consumer = setup_rdkafka_consumer
  consumer.subscribe(DT.topic)
  consumer.each do |message|
    DT[:process2] << message

    # We wait for the main Karafka process to stop, so data is not skewed by second rebalance
    sleep(0.1) until Karafka::App.terminated?

    break
  end

  consumer.close
end

start_karafka_and_wait_until do
  DT.data.key?(:process2)
end

other.join

process1 = DT[:process1].group_by(&:partition)
process2 = DT[:process2].group_by(&:partition)

process1.transform_values! { |messages| messages.map(&:raw_payload) }
process2.transform_values! { |messages| messages.map(&:payload) }

# None of messages picked up by the second process should still be present in the first process
process2.each do |partition, messages|
  messages.each do |message|
    assert_equal false, process1[partition].include?(message)
  end
end

# There should be no duplicated data received till rebalance
process1.each do |_, messages|
  assert_equal messages.size, messages.uniq.size

  previous = nil

  # All the messages in both processes should be in order
  messages
    .select { |message| message.include?(RUN) }
    .each do |message|
      current = message.split('-')[1].to_i

      assert_equal previous + 1, current if previous

      previous = current
    end
end

process2.each do |_, messages|
  assert_equal messages.size, messages.uniq.size

  previous = nil

  messages
    .select { |message| message.include?(RUN) }
    .each do |message|
      current = message.split('-')[1].to_i

      assert_equal previous + 1, current if previous

      previous = current
    end
end

DT.clear

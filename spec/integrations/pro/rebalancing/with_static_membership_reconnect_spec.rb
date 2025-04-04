# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka process when stopped and started and configured with static membership should pick up
# the assigned work. It should not be reassigned to a different process.
# Karafka should maintain all the ordering and should not have duplicated.

require 'securerandom'

setup_karafka do |config|
  config.initial_offset = 'latest'
  config.kafka[:'group.instance.id'] = SecureRandom.hex(6)
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:process2] << [message.raw_payload.to_i, message.partition]
    end
  end

  def shutdown
    DT[:process2] << :stop
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
  end
end

# @note We use external messages producer here, as the one from Karafka will be closed upon first
# process shutdown.
PRODUCER = ::WaterDrop::Producer.new do |producer_config|
  producer_config.kafka = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)
  producer_config.logger = Karafka::App.config.logger
  producer_config.max_wait_timeout = 120_000
end

Thread.new do
  nr = 0

  loop do
    2.times do |i|
      PRODUCER.produce_sync(
        topic: DT.topic,
        payload: nr.to_s,
        partition: i
      )
    end

    nr += 1

    sleep(0.1)
  end
end

# Give it some time to start sending messages
sleep(2)

# First we start the first producer, so the one that we want to track activity of, gets only
# one partition assigned, so we don't have to worry about figuring out which partition it got
other = Thread.new do
  consumer = setup_rdkafka_consumer(
    'group.instance.id': SecureRandom.hex(6),
    'auto.offset.reset': 'latest'
  )

  consumer.subscribe(DT.topic)

  consumer.each do |message|
    DT[:process1] << [message.payload.to_i, message.partition]

    break if DT.data.key?(:terminate)
  end

  consumer.close
end

# Give it some time to start before starting Karafka main process
sleep 5

start_karafka_and_wait_until(reset_status: true) do
  DT[:process2].size >= 20
end

# Wait to make sure, that the process 1 does not get the partitions back
sleep 5

# After stopping start once again

start_karafka_and_wait_until(reset_status: true) do
  DT[:process2].size >= 100
end

# Give it some time, so we allow (potentially) to assing all messages to process 1
sleep 5

# Close the first consumer instance
DT[:terminate] = true

other.join

# Initially the first started producer should get some data from both partitions before the first
# rebalance
assert_equal [0, 1], DT[:process1].map(&:last).uniq.sort

# Second process should have been stopped two times
stops_count = DT[:process2].count { |message| message == :stop }
assert_equal 2, stops_count

process2_messages = DT[:process2].select { |message| message.is_a?(Array) }

# Second process should have only one partition as joined later with static membership
assert_equal 1, process2_messages.map(&:last).uniq.size

# After getting back to the consumption, we should get all the messages with a continuity
previous = nil

process2_messages.each do |message|
  unless previous
    previous = message
    next
  end

  assert_equal previous.first + 1, message.first

  previous = message
end

# After the stop, none of the messages should be fetched by the process 1 when process 2 was not
# consuming
after = DT[:process2].index(:stop)
post_rebalance_messages = DT
                          .data[:process2]
                          .select
                          .with_index { |_, index| index > after }
                          .select { |message| message.is_a?(Array) }

assert (DT[:process1] & post_rebalance_messages).empty?

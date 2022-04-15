# frozen_string_literal: true

# Karafka should not use data that was fetched partially for a partition that was lost.
# When rebalance occurs and we're in the middle of data polling, data from a lost partition should
# be rejected as it is going to be picked up by a different process

# We simulate lost partition by starting a second consumer that will trigger a rebalance.

require 'securerandom'

RUN = SecureRandom.uuid.split('-').first

setup_karafka do |config|
  config.max_wait_time = 50_000
  config.max_messages = 1_000
  config.initial_offset = 'earliest'
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[:process1] << message
    end
  end

  def revoked
    DataCollector.data[:revoked] = messages.metadata.partition
  end
end

draw_routes do
  consumer_group 'integrations_0_02' do
    topic 'integrations_0_02' do
      consumer Consumer
    end
  end
end

Thread.new do
  nr = 0

  loop do
    2.times do |i|
      # If revoked, we are stopping, so producer will be closed
      break if DataCollector.data.key?(:revoked)

      produce('integrations_0_02', "#{RUN}-#{nr}-#{i}", partition: i)
    end

    nr += 1

    sleep(0.2)
  end
end

other = Thread.new do
  # We give it a bit of time, so we make sure we have something in the buffer
  sleep(10)

  config = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': Karafka::App.consumer_groups.first.id,
    'auto.offset.reset': 'earliest'
  }
  consumer = Rdkafka::Config.new(config).consumer
  consumer.subscribe('integrations_0_02')
  consumer.each do |message|
    DataCollector.data[:process2] << message

    # We wait for the main Karafka process to stop, so data is not skewed by second rebalance
    sleep(0.1) until Karafka::App.stopped?

    consumer.close
    break
  end
end

start_karafka_and_wait_until do
  DataCollector.data.key?(:process2)
end

other.join

process1 = DataCollector.data[:process1].group_by(&:partition)
process2 = DataCollector.data[:process2].group_by(&:partition)

process1.transform_values! { |messages| messages.map(&:raw_payload) }
process2.transform_values! { |messages| messages.map(&:payload) }

# None of messages picked up by the second process should still be present in the first process
process2.each do |partition, messages|
  messages.each do |message|
    assert_equal false, process1[partition].include?(message)
  end
end

# There should be no duplicated data received
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

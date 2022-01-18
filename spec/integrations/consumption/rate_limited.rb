# frozen_string_literal: true

# Karafka should be able to use pause to rate limit when consumption is tracked
# We can do it by using the pausing capabilities.
# While it is rather not recommended, but for the sake of demo and making sure things work as
# expected, we us it

setup_karafka do |config|
  # Throttle for a second
  config.pause_timeout = 1_000
  config.max_wait_time = 500
  config.max_messages = 1
end

elements = Array.new(50) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def initialize
    super
    @seconds_available = 5
  end

  def consume
    # Lets say we want to process at most 5 messages per second and that processing one takes 0.2s
    # which means we can process at most 5 messages before pausing for a second
    messages.each do |message|
      DataCollector.data[0] << message.raw_payload

      @seconds_available -= 1

      next unless @seconds_available.zero?

      DataCollector.data[:pauses] << Time.now.to_f
      @seconds_available = 5
      client.pause(topic.name, message.partition, message.offset + 1)
      pause.pause

      break
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

elements.each { |data| produce(DataCollector.topic, data) }

started_at = Time.now.to_f

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 50
end

# Since we have 5 messages and we sleep 1, for 50 messages it would mean at least 9 seconds
# assuming, that all the other things take 0 time (since the pause after last is irrelevant as
# we shutdown)
assert_equal true, (Time.now.to_f - started_at) >= 9
assert_equal elements, DataCollector.data[0]
# We should pause 10 times, once every 5 messages
assert_equal 10, DataCollector.data[:pauses].count

# Distance in between pauses should be more or less 1 second
previous_pause_time = nil

DataCollector.data[:pauses].each do |pause_time|
  if previous_pause_time
    distance = pause_time - previous_pause_time

    p distance

    assert_equal true, distance >= 1
    assert_equal true, distance <= 2
  end

  previous_pause_time = pause_time
end

# frozen_string_literal: true

# Karafka should be able to recover from non-critical error with same consumer instance and it
# also should emit an event with error details that can be logged

class Listener
  def on_consumer_consume_error(event)
    DataCollector.data[:error] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka

elements = Array.new(5) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    @count ||= 0
    @count += 1

    messages.each { |message| DataCollector.data[0] << message.raw_payload }
    DataCollector.data[1] << object_id

    raise StandardError if @count == 1
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

start_karafka_and_wait_until do
  # We have 5 messages but we retry thus it needs to be minimum 6
  DataCollector.data[0].size >= 6
end

assert_equal true, DataCollector.data[0].size >= 6
assert_equal 1, DataCollector.data[1].uniq.size
assert_equal StandardError, DataCollector.data[:error].first[:error].class
assert_equal 5, DataCollector.data[0].uniq.size

# frozen_string_literal: true

# Karafka should not recover from critical errors that happened in the workers while consuming
# jobs. Those should be handled by the users and the worker with the process should abort.

setup_karafka do |config|
  config.concurrency = 1
end

class Listener
  def on_worker_process_error(event)
    DataCollector.data[0] << 1
  end
end

SuperException = Class.new(Exception)

Karafka.monitor.subscribe(Listener.new)

numbers = Array.new(5) { rand.to_s }

class Consumer < Karafka::BaseConsumer
  def consume
    raise SuperException
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

numbers.each { |data| produce(DataCollector.topic, data) }

raised = false

begin
  start_karafka_and_wait_until do
    # This means, that listener received critical error
    DataCollector.data[0].size >= 1
  end
rescue SuperException
  raised = true
end

assert_equal true, raised
assert_equal 1, DataCollector.data[0].size

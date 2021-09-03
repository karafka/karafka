# frozen_string_literal: true

# Karafka should not recover from critical errors that happened in the workers while consuming
# jobs. Those should be handled by the users and the worker with the process should abort.
#
# @note This test is a bit special as due to how Karafka operates, when unexpected issue happens
#   in particular moments, it can bubble up and exit 2

root_path = File.expand_path(
  File.join(
    File.dirname(__FILE__),
    '../../'
  )
)

root_path = Pathname.new(root_path)

# We require it here, so when forked, all those things are already in the child processes
require root_path.join('spec/integrations_helper.rb')

setup_karafka do |config|
  config.concurrency = 1
  config.shutdown_timeout = 1_000
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

# frozen_string_literal: true

# Karafka shutdown jobs should run in workers threads, not form the fetcher thread

setup_karafka do |config|
  # This will ensure all work runs from one worker thread
  config.concurrency = 1
end

# This will allow us to establish the listener thread id. Shutdown jobs should run from the
# worker threads
Karafka::App.monitor.subscribe('connection.listener.before_fetch_loop') do
  DataCollector[:listener_thread_id] = Thread.current.object_id
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector[:worker_thread_id] = Thread.current.object_id
  end

  def on_shutdown
    DataCollector[:shutdown_thread_id] = Thread.current.object_id
  end
end

draw_routes(Consumer)

produce(DataCollector.topic, '1')

start_karafka_and_wait_until do
  DataCollector.data.key?(:worker_thread_id)
end

assert DataCollector.data.key?(:listener_thread_id)
assert DataCollector.data.key?(:worker_thread_id)
assert DataCollector.data.key?(:shutdown_thread_id)
assert DataCollector[:listener_thread_id] != DataCollector[:worker_thread_id]
assert_equal DataCollector[:worker_thread_id], DataCollector[:shutdown_thread_id]

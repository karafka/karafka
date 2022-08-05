# frozen_string_literal: true

# Karafka shutdown jobs should run in workers threads, not form the fetcher thread

setup_karafka do |config|
  # This will ensure all work runs from one worker thread
  config.concurrency = 1
end

# This will allow us to establish the listener thread id. Shutdown jobs should run from the
# worker threads
Karafka::App.monitor.subscribe('connection.listener.before_fetch_loop') do
  DT[:listener_thread_id] = Thread.current.object_id
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:worker_thread_id] = Thread.current.object_id
  end

  def shutdown
    DT[:shutdown_thread_id] = Thread.current.object_id
  end
end

draw_routes(Consumer)

produce(DT.topic, '1')

start_karafka_and_wait_until do
  DT.data.key?(:worker_thread_id)
end

assert DT.data.key?(:listener_thread_id)
assert DT.data.key?(:worker_thread_id)
assert DT.data.key?(:shutdown_thread_id)
assert DT[:listener_thread_id] != DT[:worker_thread_id]
assert_equal DT[:worker_thread_id], DT[:shutdown_thread_id]

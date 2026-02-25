# frozen_string_literal: true

# When reconfiguring the worker thread priority, worker threads should have proper priority set
# When reconfiguring internal listener worker thread priority, it should also work

setup_karafka do |config|
  config.worker_thread_priority = 2
  config.internal.connection.listener_thread_priority = -2
end

Karafka::App.monitor.subscribe("connection.listener.fetch_loop") do
  DT[:listener_thread_priority] = Thread.current.priority
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:worker_thread_priority] = Thread.current.priority
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal DT[:worker_thread_priority], 2
assert_equal DT[:listener_thread_priority], -2

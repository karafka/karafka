# frozen_string_literal: true

# When configuring workers via the nested `workers` namespace, concurrency and thread priority
# should be respected by the workers pool and the deprecated root-level aliases should read the
# same values

setup_karafka do |config|
  config.workers.concurrency = 2
  config.workers.thread_priority = 2
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:worker_thread_priority] = Thread.current.priority
    DT[:pool_size] = Karafka::Server.workers.size
    DT[:done] = true
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:done)
end

assert_equal 2, DT[:worker_thread_priority]
assert_equal 2, DT[:pool_size]
assert_equal 2, Karafka::App.config.concurrency
assert_equal 2, Karafka::App.config.worker_thread_priority

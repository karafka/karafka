# frozen_string_literal: true

# When using the fibers workers backend, IO-bound jobs from independent topics should run
# concurrently as fibers multiplexed on a single carrier thread

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
  config.workers.carrier_threads = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:threads] << Thread.current.name
    DT[:starts] << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Scheduler-aware blocking operation. With plain threads a single thread could never run
    # two of those concurrently; with fibers on one carrier thread they overlap
    sleep(2)
    DT[:stops] << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    DT[topic.name] = true
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
  end

  topic DT.topics[1] do
    consumer Consumer
  end
end

produce_many(DT.topics[0], DT.uuids(1))
produce_many(DT.topics[1], DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(DT.topics[0]) && DT.key?(DT.topics[1])
end

# The fibers backend was resolved
assert_equal(
  Karafka::Processing::WorkersPools::Fibers,
  Karafka::App.config.internal.processing.workers_pool_class
)

# Both jobs ran on the same, single carrier thread
assert_equal ["karafka.carrier#0"], DT[:threads].uniq

# And their processing overlapped in time, which a single thread can only do with fibers
intervals = DT[:starts].zip(DT[:stops])
overlap = intervals.combination(2).any? do |(start1, stop1), (start2, stop2)|
  start1 < stop2 && start2 < stop1
end

assert overlap, "expected fiber jobs to overlap on the carrier thread"

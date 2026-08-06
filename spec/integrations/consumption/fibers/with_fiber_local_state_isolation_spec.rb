# frozen_string_literal: true

# When running the fibers workers backend, `Thread.current[]` storage is fiber-local in Ruby,
# so concurrent jobs interleaving on the same carrier thread must not see each other's state

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
  config.workers.carrier_threads = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    Thread.current[:fiber_state] = topic.name

    # Long enough for both jobs to interleave on the single carrier thread
    sleep(1)

    DT[topic.name] = Thread.current[:fiber_state]
    DT[:carriers] << Thread.current.name
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

# Despite interleaving on one carrier thread, each job kept its own fiber-local state
assert_equal DT.topics[0], DT[DT.topics[0]]
assert_equal DT.topics[1], DT[DT.topics[1]]
assert_equal ["karafka.carrier#0"], DT[:carriers].uniq

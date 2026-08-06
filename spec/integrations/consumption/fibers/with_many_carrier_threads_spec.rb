# frozen_string_literal: true

# When running the fibers workers backend with multiple carrier threads, work should execute
# on fibers spread across the carriers

setup_karafka do |config|
  config.workers.backend = :fibers
  # One fiber per carrier: concurrent jobs are then guaranteed to use distinct carriers
  config.workers.concurrency = 3
  config.workers.carrier_threads = 3
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:threads] << Thread.current.name

    sleep(1)

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

  topic DT.topics[2] do
    consumer Consumer
  end
end

3.times { |i| produce_many(DT.topics[i], DT.uuids(1)) }

start_karafka_and_wait_until do
  DT.key?(DT.topics[0]) && DT.key?(DT.topics[1]) && DT.key?(DT.topics[2])
end

# All jobs ran on carrier threads
assert(DT[:threads].all? { |name| name.match?(/karafka\.carrier#\d+/) }, DT[:threads])

# With one fiber per carrier, concurrent jobs had to use more than one carrier
assert DT[:threads].uniq.size >= 2, DT[:threads]

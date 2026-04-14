# frozen_string_literal: true

# When a consumer scales the workers pool up, new worker threads should be created and the pool
# size should increase. Messages should continue to be processed correctly after scaling.

setup_karafka do |config|
  config.concurrency = 2
end

Karafka.monitor.subscribe("worker.scaling.up") do |event|
  DT[:scale_up_events] << {
    from: event.payload[:from],
    to: event.payload[:to]
  }
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:messages] << message.raw_payload
    end

    # Scale up on first batch only
    unless DT.key?(:scaled)
      DT[:size_before] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(5)
      DT[:size_after] = Karafka::Server.workers.size
      DT[:scaled] = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:messages].size >= 20
end

# Pool size should have grown
assert_equal 2, DT[:size_before]
assert_equal 5, DT[:size_after]

# Instrumentation events: one from initial boot (0→2), one from consumer scale (2→5)
assert_equal 2, DT[:scale_up_events].size

boot_event = DT[:scale_up_events].first
assert_equal 0, boot_event[:from]
assert_equal 2, boot_event[:to]

scale_event = DT[:scale_up_events].last
assert_equal 2, scale_event[:from]
assert_equal 5, scale_event[:to]

# All messages should have been consumed
assert_equal elements.size, DT[:messages].size

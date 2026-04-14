# frozen_string_literal: true

# When a consumer attempts to scale to 0 or a negative number, the pool should clamp to a minimum
# of 1 worker. The pool must never have zero workers as that would halt all processing.

setup_karafka do |config|
  config.concurrency = 3
end

Karafka.monitor.subscribe("worker.scaling.down") do |event|
  DT[:scale_down_events] << {
    from: event.payload[:from],
    to: event.payload[:to]
  }
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

    unless DT.key?(:scaled)
      DT[:size_before] = Karafka::Server.workers.size

      # Scale to 0 — should clamp to 1
      Karafka::Server.workers.scale(0)
      # Give workers time to pick up nil sentinels and exit
      sleep(2)
      DT[:size_after_zero] = Karafka::Server.workers.size

      # Scale to -5 — should remain at 1 (already at minimum)
      Karafka::Server.workers.scale(-5)
      sleep(1)
      DT[:size_after_negative] = Karafka::Server.workers.size

      DT[:scaled] = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:scaled) && DT[:messages].size >= 20
end

# Started with 3
assert_equal 3, DT[:size_before]

# After scaling to 0, should have clamped to 1
assert_equal 1, DT[:size_after_zero]

# After scaling to -5, should still be 1
assert_equal 1, DT[:size_after_negative]

# Scale down event from 3→1 (clamped from target 0)
assert_equal 1, DT[:scale_down_events].size
assert_equal 3, DT[:scale_down_events].first[:from]
assert_equal 1, DT[:scale_down_events].first[:to]

# No additional scale up events beyond boot (only 0→3 from boot)
assert_equal 1, DT[:scale_up_events].size

# All messages should still be consumed with just 1 worker
assert_equal elements.size, DT[:messages].size

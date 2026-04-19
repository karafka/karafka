# frozen_string_literal: true

# When a consumer scales to the same size as the current pool, it should be a no-op. No scaling
# events should be emitted and the pool size should remain unchanged.

setup_karafka do |config|
  config.concurrency = 3
end

Karafka.monitor.subscribe("worker.scaling.up") do |event|
  DT[:scale_up_events] << {
    from: event.payload[:from],
    to: event.payload[:to]
  }
end

Karafka.monitor.subscribe("worker.scaling.down") do |event|
  DT[:scale_down_events] << {
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
      # Scale to the same size — should be a no-op
      Karafka::Server.workers.scale(3)
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

# Size unchanged
assert_equal 3, DT[:size_before]
assert_equal 3, DT[:size_after]

# Only the boot scale up event (0→3), no additional events
assert_equal 1, DT[:scale_up_events].size
assert_equal 0, DT[:scale_up_events].first[:from]
assert_equal 3, DT[:scale_up_events].first[:to]

# No scale down events at all
assert_equal 0, DT[:scale_down_events].size

# All messages consumed
assert_equal elements.size, DT[:messages].size

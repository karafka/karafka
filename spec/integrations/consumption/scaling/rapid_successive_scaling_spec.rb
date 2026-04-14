# frozen_string_literal: true

# When a consumer issues multiple rapid scale calls in succession, the pool should handle all of
# them correctly without race conditions. The final pool size should reflect the last scale call.

setup_karafka do |config|
  config.concurrency = 2
  config.max_messages = 5
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
      DT[:initial_size] = Karafka::Server.workers.size

      # Rapid successive scaling: up, up more, then down
      Karafka::Server.workers.scale(5)
      Karafka::Server.workers.scale(10)
      Karafka::Server.workers.scale(4)

      # Give workers time to pick up nil sentinels from the downscale
      sleep(2)

      DT[:final_size] = Karafka::Server.workers.size
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

# Started with 2
assert_equal 2, DT[:initial_size]

# Final size should be 4 (the last scale call)
assert_equal 4, DT[:final_size]

# Scale up events: boot (0→2), consumer (2→5), consumer (5→10)
assert_equal 3, DT[:scale_up_events].size

# Scale down event: consumer (10→4)
assert_equal 1, DT[:scale_down_events].size
assert_equal 10, DT[:scale_down_events].first[:from]
assert_equal 4, DT[:scale_down_events].first[:to]

# All messages consumed despite rapid scaling
assert_equal elements.size, DT[:messages].size

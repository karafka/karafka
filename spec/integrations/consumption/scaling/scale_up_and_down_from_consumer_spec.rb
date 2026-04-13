# frozen_string_literal: true

# When a consumer scales the workers pool up and then down, the pool should handle both transitions
# correctly. Worker threads should be added and removed as expected with proper instrumentation
# events emitted for each scaling operation.

setup_karafka do |config|
  config.concurrency = 3
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

    unless DT.key?(:scaled_up)
      DT[:initial_size] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(8)
      DT[:size_after_up] = Karafka::Server.workers.size
      DT[:scaled_up] = true

      return
    end

    unless DT.key?(:scaled_down)
      Karafka::Server.workers.scale(2)
      # Give workers time to pick up the nil sentinels and exit
      sleep(0.5)
      DT[:size_after_down] = Karafka::Server.workers.size
      DT[:scaled_down] = true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT.key?(:scaled_down) && DT[:messages].size >= 20
end

# Initial size should be the configured concurrency
assert_equal 3, DT[:initial_size]

# After scaling up
assert_equal 8, DT[:size_after_up]

# After scaling down
assert_equal 2, DT[:size_after_down]

# Scale up events: one from boot (0→3), one from consumer (3→8)
assert_equal 2, DT[:scale_up_events].size

boot_event = DT[:scale_up_events].first
assert_equal 0, boot_event[:from]
assert_equal 3, boot_event[:to]

consumer_up_event = DT[:scale_up_events].last
assert_equal 3, consumer_up_event[:from]
assert_equal 8, consumer_up_event[:to]

# Scale down event: one from consumer (8→2)
assert_equal 1, DT[:scale_down_events].size
assert_equal 8, DT[:scale_down_events].first[:from]
assert_equal 2, DT[:scale_down_events].first[:to]

# All messages should have been consumed despite pool changes
assert_equal elements.size, DT[:messages].size

# frozen_string_literal: true

# When a consumer attempts to scale up during Karafka shutdown, the scaling should still work
# without errors. The pool should accept new workers even while the app is stopping, since
# shutdown waits for in-flight work to complete before terminating threads.

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

    unless DT.key?(:scaled)
      # Initiate shutdown first, then try to scale up while stopping
      Thread.new { Karafka::Server.stop }

      # Give the stop signal a moment to propagate
      sleep(0.5)

      DT[:stopping_when_scaled] = Karafka::App.stopping?
      DT[:size_before] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(5)
      DT[:size_after] = Karafka::Server.workers.size
      DT[:scaled] = true
    end
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT.key?(:scaled)
end

# Should have been stopping when we tried to scale
assert_equal true, DT[:stopping_when_scaled]

# Pool should have grown despite shutdown being in progress
assert_equal 2, DT[:size_before]
assert_equal 5, DT[:size_after]

# Scale up events: boot (0→2) + consumer (2→5)
assert_equal 2, DT[:scale_up_events].size

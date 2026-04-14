# frozen_string_literal: true

# When a consumer attempts to scale down during Karafka shutdown, the scaling should still work
# without errors. Nil sentinels should be enqueued and workers should exit gracefully even though
# the queue is about to be closed for shutdown.

setup_karafka do |config|
  config.concurrency = 5
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
      # Initiate shutdown first, then try to scale down while stopping
      Thread.new { Karafka::Server.stop }

      # Give the stop signal a moment to propagate
      sleep(0.5)

      DT[:stopping_when_scaled] = Karafka::App.stopping?
      DT[:size_before] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(2)
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

# Pool should have had 5 workers before the scale request
assert_equal 5, DT[:size_before]

# Scale down event should have been emitted with the target
assert_equal 1, DT[:scale_down_events].size
assert_equal 5, DT[:scale_down_events].first[:from]
assert_equal 2, DT[:scale_down_events].first[:to]

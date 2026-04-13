# frozen_string_literal: true

# When a consumer scales the workers pool down, excess worker threads should exit gracefully and
# the pool size should decrease. Messages should continue to be processed correctly after scaling.

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

    # Scale down on first batch only
    unless DT.key?(:scaled)
      DT[:size_before] = Karafka::Server.workers.size
      Karafka::Server.workers.scale(2)
      # Give workers time to pick up the nil sentinels and exit
      sleep(0.5)
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

# Pool size should have shrunk
assert_equal 5, DT[:size_before]
assert_equal 2, DT[:size_after]

# Instrumentation event should have fired
assert_equal 1, DT[:scale_down_events].size
assert_equal 5, DT[:scale_down_events].first[:from]
assert_equal 2, DT[:scale_down_events].first[:to]

# All messages should have been consumed
assert_equal elements.size, DT[:messages].size

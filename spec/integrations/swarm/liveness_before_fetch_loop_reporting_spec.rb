# frozen_string_literal: true

# The liveness listener should report healthy on before_fetch_loop so the supervisor has an
# initial healthy report before any consumption starts. This prevents the supervisor from killing
# a node whose first consumption takes longer than the report timeout.

MACOS = RUBY_PLATFORM.include?("darwin")

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  # Short report timeout so the test would fail fast without the before_fetch_loop report
  config.internal.swarm.node_report_timeout = MACOS ? 5_000 : 3_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    # Simulate a long first consumption that, combined with startup and assignment overhead,
    # could approach or exceed the report timeout without the before_fetch_loop report.
    unless DT.key?(:consumed)
      DT[:consumed] = true
      sleep(MACOS ? 4 : 2)
    end

    WRITER.puts("1")
    WRITER.flush
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

stoppings = []
Karafka::App.monitor.subscribe("swarm.manager.stopping") do |event|
  stoppings << event[:status]
end

produce_many(DT.topic, DT.uuids(10))

done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 1
end

# Node should not have been stopped by the supervisor - it survived thanks to the
# before_fetch_loop report
assert_equal [], stoppings

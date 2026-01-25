# frozen_string_literal: true

# Karafka should not wait full long polling cycle when shutdown is issued due to fast circuit
# breaker flow. No assertions are needed as it will just wait forever if not working correctly

setup_karafka do |config|
  config.max_messages = 1
  config.shutdown_timeout = 150_000_000
  config.max_wait_time = 100_000_000
  config.internal.swarm.node_report_timeout = 200_000_000
end

2.times { produce(DT.topic, "1") }

Karafka.monitor.subscribe("connection.listener.fetch_loop") do
  DT[:runs] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << true
  end
end

draw_routes(Consumer, create_topics: false)

start_karafka_and_wait_until do
  if DT[0].size >= 2
    sleep(2)
    true
  else
    false
  end
end

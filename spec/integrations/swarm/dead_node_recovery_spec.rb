# frozen_string_literal: true

# After node dies (for any reason), it should be restarted by the supervisor
setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  # Enhance rebalance time on dead nodes
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts('1')
    WRITER.flush
    exit!
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

# No specs needed as only if new nodes start, this will happen more than once
done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 2
end

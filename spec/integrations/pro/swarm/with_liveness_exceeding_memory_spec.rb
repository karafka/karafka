# frozen_string_literal: true

# If we use liveness API to report issue, Karafka should restart the node

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 10_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new(
    # This is below what we use on start, so it will terminate quite fast
    memory_limit: '10MB'
  )
)

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:reported)
      WRITER.puts('1')
      WRITER.flush
      DT[:reported] = true
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

# No specs needed as only if new nodes start, this will happen more than once
done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 2
end

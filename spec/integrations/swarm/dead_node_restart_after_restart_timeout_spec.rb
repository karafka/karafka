# frozen_string_literal: true

# After a node dies, the supervisor should start a new one once `node_restart_timeout` passes,
# without waiting for the next `supervision_interval` check

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 60_000
end

READER, WRITER = IO.pipe

Karafka::App.monitor.subscribe("swarm.manager.before_fork") do
  DT[:forks] << Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts(Process.clock_gettime(Process::CLOCK_MONOTONIC))
    WRITER.flush
    exit!
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until(mode: :swarm) do
  DT[:died_at] = READER.gets.to_f unless DT.key?(:died_at)
  DT[:forks].size >= 2
end

restart_delay = DT[:forks].last - DT[:died_at]

assert restart_delay >= 1
assert restart_delay < 10

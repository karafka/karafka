# frozen_string_literal: true

# When the supervisor gets quiet while a dead node waits for its restart, it should not restart
# it and should not spin waiting for that restart

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 3_000
  config.internal.swarm.supervision_interval = 60_000
end

READER, WRITER = IO.pipe

Karafka::App.monitor.subscribe("swarm.manager.before_fork") do
  DT[:forks] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("1")
    WRITER.flush
    exit!
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
  # Give the supervisor time to clean up the dead node before it gets quiet
  sleep(1)
  Process.kill("TSTP", Process.pid)

  # Past the restart window
  sleep(3)
  cpu_before = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  sleep(3)
  DT[:cpu] = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_before

  true
end

assert_equal 1, DT[:forks].size
assert DT[:cpu] < 1

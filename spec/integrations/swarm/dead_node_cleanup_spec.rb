# frozen_string_literal: true

# After node dies (for any reason), it should be cleaned up and not left hanging as a zombie
setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  # Enhance rebalance time on dead nodes
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

pids = []

Karafka::App.monitor.subscribe('swarm.manager.after_fork') do |event|
  pids << event[:node].pid
  DT[:execution_mode] = Karafka::Server.execution_mode
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

done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 2
end

def zombie_process?(pid)
  status = File.read("/proc/#{pid}/status")
  status.include?('(zombie)')
rescue Errno::ENOENT
  false
end

# Ensure that they are not present as zombies
pids.each do |pid|
  assert !zombie_process?(pid)
end

assert_equal :supervisor, DT[:execution_mode]

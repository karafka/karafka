# frozen_string_literal: true

# When nodes restart, the supervisor should close old reader pipes to prevent FD leaks.
# Each node restart creates a new IO.pipe pair in Node#start. Without proper cleanup,
# old reader pipe FDs accumulate in the supervisor process, eventually hitting OS limits.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("1")
    WRITER.flush
    exit!
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(10))

def count_pipe_fds
  Dir.glob("/proc/self/fd/*").count do |fd_path|
    File.readlink(fd_path).start_with?("pipe:")
  rescue Errno::ENOENT
    false
  end
end

Karafka::App.monitor.subscribe("swarm.manager.after_fork") do
  DT[:pipe_counts] << count_pipe_fds
end

done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 5
end

pipe_counts = DT[:pipe_counts]

# We should have at least 5 forks (1 initial + 4 restarts)
assert pipe_counts.size >= 5

# After multiple node restarts, pipe FD count in the supervisor should remain stable.
# With the leak: each restart adds 1 orphaned reader pipe FD, so we see linear growth.
# Without the leak: old readers are closed before creating new pipes, count stays stable.
growth = pipe_counts.last - pipe_counts.first
assert growth <= 2, "Pipe FDs grew by #{growth} (#{pipe_counts.first} -> #{pipe_counts.last}), indicating a leak"

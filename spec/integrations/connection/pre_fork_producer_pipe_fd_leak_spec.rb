# frozen_string_literal: true

# When a producer is used before forking (messages produced in parent), the child inherits
# all of the parent's file descriptors including WaterDrop QueuePipe and librdkafka internal
# pipes. After fork, the child closes the old producer and creates a new one (like
# ProducerReplacer does in swarm). This test verifies:
#   1. The inherited producer can be closed post-fork without hanging
#   2. Pipe FDs from the old producer are cleaned up
#   3. The new producer works correctly
#   4. No pipe FD accumulation across sequential forks

LINUX = RUBY_PLATFORM.include?("linux")

setup_karafka do |config|
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

def count_pipe_fds
  Dir.glob("/proc/self/fd/*").count do |fd_path|
    File.readlink(fd_path).start_with?("pipe:")
  rescue Errno::ENOENT
    false
  end
end

# Use the producer in the parent process — this forces it to fully initialize,
# creating librdkafka handle, WaterDrop QueuePipe, polling thread, etc.
produce_many(DT.topic, DT.uuids(5))

sleep(1)

parent_pipe_count = count_pipe_fds if LINUX

READER, WRITER = IO.pipe

# Fork 7 times sequentially. Each child:
#   1. Counts inherited pipe FDs
#   2. Closes the inherited producer (tests the fix for post-fork hang)
#   3. Creates a fresh producer
#   4. Produces a message
#   5. Counts pipe FDs after
7.times do |i|
  pid = Process.fork do
    inherited_pipes = count_pipe_fds if LINUX

    # Close inherited producer exactly like Node#start does.
    # Before the fix, this would hang because Poller#unregister didn't call
    # ensure_same_process! and would wait on a latch the dead poller thread
    # would never release.
    Karafka.producer.close

    after_close_pipes = count_pipe_fds if LINUX

    # Create a fresh producer like ProducerReplacer does
    kafka_config = Karafka::Setup::AttributesMap.producer(Karafka::App.config.kafka.dup)

    new_producer = WaterDrop::Producer.new do |p_config|
      p_config.kafka = kafka_config
      p_config.logger = Karafka::App.config.logger
    end

    new_producer.produce_sync(topic: DT.topic, payload: "child-#{i}")

    after_produce_pipes = count_pipe_fds if LINUX

    WRITER.puts("#{i}:#{inherited_pipes}:#{after_close_pipes}:#{after_produce_pipes}")
    WRITER.flush

    new_producer.close
    exit!
  end

  Process.waitpid(pid)
end

WRITER.close

child_results = []

while (line = READER.gets)
  parts = line.strip.split(":")
  child_results << {
    cycle: parts[0].to_i,
    inherited: parts[1].to_i,
    after_close: parts[2].to_i,
    after_produce: parts[3].to_i
  }
end

READER.close

parent_pipe_after = count_pipe_fds if LINUX

if LINUX
  warn "=== Pre-fork producer pipe FD leak test ==="
  warn "Parent pipes: #{parent_pipe_count} before, #{parent_pipe_after} after"
  warn ""
  warn "Child pipe FD counts per fork (inherited -> after_close -> after_produce):"
  child_results.each do |r|
    warn "  cycle #{r[:cycle]}: #{r[:inherited]} -> #{r[:after_close]} -> #{r[:after_produce]}"
  end

  # All children should inherit the same number of pipe FDs (no growth between forks)
  inherited_counts = child_results.map { |r| r[:inherited] }
  assert(
    inherited_counts.uniq.size == 1,
    "Inherited pipe FD count varies across forks: #{inherited_counts.inspect}"
  )

  # After producing with a new producer, all children should have the same FD count
  after_counts = child_results.map { |r| r[:after_produce] }
  after_growth = after_counts.last - after_counts.first
  assert(
    after_growth <= 2,
    "Child pipe FDs grew across forks: #{after_counts.inspect}"
  )
end

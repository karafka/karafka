# frozen_string_literal: true

# When supervisor stops work, hanging processes should be killed

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 2_000
end

READER, WRITER = IO.pipe

# Redefine it so it takes longer than supervisor forceful kill
Karafka::App.monitor.subscribe('swarm.node.after_fork') do
  Karafka::App.config.shutdown_timeout = 60_000
end

stoppings = []
Karafka::App.monitor.subscribe('swarm.manager.stopping') do
  stoppings << true
end

terminations = []
Karafka::App.monitor.subscribe('swarm.manager.terminating') do
  terminations << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts('1')
    sleep
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
end

def process_exists?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH
  false
end

assert_equal 2, stoppings.size
assert_equal 2, terminations.size

# All should be dead
Karafka::App.config.internal.swarm.manager.nodes.each do |node|
  assert !process_exists?(node.pid)
end

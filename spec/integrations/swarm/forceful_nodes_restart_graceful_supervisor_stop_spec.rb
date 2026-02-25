# frozen_string_literal: true

# When supervisor restarts nodes that are hanging it should emit a status and when nodes are
# no longer hanging it should gracefully stop

# macOS ARM64 needs more generous timeouts due to slower process startup
MACOS = RUBY_PLATFORM.include?("darwin")

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 5_000
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = MACOS ? 2_000 : 1_000
  config.internal.swarm.supervision_interval = MACOS ? 2_000 : 1_000
  config.internal.swarm.node_report_timeout = MACOS ? 5_000 : 2_000
end

Karafka::App.monitor.subscribe("swarm.manager.before_fork") do
  DT[:forks] << true

  # Give them a bit more time if they are suppose to be legit
  Karafka::App.config.shutdown_timeout = 30_000 if DT[:forks].size >= 3
end

# Make it do nothing so we simulate hanging process
module Karafka
  module Swarm
    class LivenessListener
      def on_statistics_emitted(_event)
        periodically do
          Kernel.exit!(orphaned_exit_code) if node.orphaned?

          if DT[:forks].size > 2
            node.healthy
          else
            # Fake hang it forever
            sleep
          end
        end
      end
    end
  end
end

stoppings = []
Karafka::App.monitor.subscribe("swarm.manager.stopping") do |event|
  stoppings << event[:status]
end

terminations = []
Karafka::App.monitor.subscribe("swarm.manager.terminating") do
  terminations << true
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until(mode: :swarm) do
  if DT[:forks].size < 3
    false
  else
    Karafka::App.config.shutdown_timeout = 100_000
    # Sleep is needed on macOS to allow node to start and be responsive enough for shutdown
    sleep(2) if MACOS

    true
  end
end

def process_exists?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH
  false
end

assert_equal [-1], stoppings.uniq
assert_equal 2, stoppings.size
assert_equal 2, terminations.size

# All should be dead
Karafka::App.config.internal.swarm.manager.nodes.each do |node|
  assert !process_exists?(node.pid)
end

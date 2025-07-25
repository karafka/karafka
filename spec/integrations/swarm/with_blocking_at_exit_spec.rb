# frozen_string_literal: true

# When supervisor stops work but do not stop because of blocking `at_exit` in them, supervisor
# should kill them

setup_karafka(allow_errors: true) do |config|
  config.shutdown_timeout = 2_000
end

READER, WRITER = IO.pipe

# Redefine it so it takes longer than supervisor forceful kill
Karafka::App.monitor.subscribe('swarm.node.after_fork') do
  # Simulate a situation where a broken gem would post-fork block the process shutdown
  at_exit do
    sleep(60)
  end
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

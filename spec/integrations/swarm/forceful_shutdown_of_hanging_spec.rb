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

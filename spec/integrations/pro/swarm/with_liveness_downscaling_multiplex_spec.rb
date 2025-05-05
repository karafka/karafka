# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Liveness reporter should be totally ok with connections downscaling when using multiplexing
# and should not see it as a problem

setup_karafka do |config|
  config.swarm.nodes = 1
  c_klass = config.internal.connection.conductor.class
  config.internal.connection.conductor = c_klass.new(1_000)
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new(
    polling_ttl: 5_000
  )
)

# The downscale should not cause monitor to think this listener is hanging
# If this crashes under this scenario, it means it does
Karafka.monitor.subscribe('swarm.manager.before_fork') do
  DT[:forks] << 1

  raise if DT[:forks].size > 1
end

Karafka.monitor.subscribe('connection.listener.stopped') do
  WRITER.puts('1')
  WRITER.flush
end

Karafka.monitor.subscribe('swarm.manager.stopping') do |event|
  raise if event[:status].positive?
end

class Consumer < Karafka::BaseConsumer
  def consume; end
end

draw_routes do
  subscription_group do
    multiplexing(min: 1, max: 2, boot: 2, scale_delay: 1_000)

    topic DT.topic do
      consumer Consumer
    end
  end
end

start_karafka_and_wait_until(mode: :swarm) do
  DT.key?(:forks) && READER.gets && sleep(10)
end

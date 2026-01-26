# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
Karafka.monitor.subscribe("swarm.manager.before_fork") do
  DT[:forks] << 1

  raise if DT[:forks].size > 1
end

Karafka.monitor.subscribe("connection.listener.stopped") do
  WRITER.puts("1")
  WRITER.flush
end

Karafka.monitor.subscribe("swarm.manager.stopping") do |event|
  raise if event[:status].positive?
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
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

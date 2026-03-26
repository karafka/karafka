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

# When a long running job consumer exceeds the consuming_ttl, liveness should report unhealthy
# and the supervisor should kill and restart the node.
# This simulates the real-world scenario where LRJ processing takes longer than the consuming_ttl
# and the node gets killed despite LRJ being designed for long processing.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new(
    consuming_ttl: 1_000
  )
)

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:reported)
      WRITER.puts("1")
      WRITER.flush
      DT[:reported] = true
    end

    sleep(10)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

# No specs needed as only if new nodes start, this will happen more than once
done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 2
end

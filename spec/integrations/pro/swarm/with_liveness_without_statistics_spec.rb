# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When statistics are disabled (statistics.interval.ms = 0), the liveness listener should still
# report healthy via on_connection_listener_fetch_loop. The node should NOT be killed.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.kafka[:"statistics.interval.ms"] = 0
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
  config.internal.swarm.node_report_timeout = 5_000
end

READER, WRITER = IO.pipe

# Track forks — if more than one fork happens, the node was killed and restarted
Karafka.monitor.subscribe("swarm.manager.before_fork") do
  WRITER.puts("1")
  WRITER.flush
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumed] = true
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

done = []

start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets

  # If we see a second fork, the node was killed — that should NOT happen anymore
  raise "Node was killed despite fetch loop liveness reporting" if done.size >= 2

  # Wait long enough for node_report_timeout to have passed
  done.size >= 1 && sleep(15) && true
end

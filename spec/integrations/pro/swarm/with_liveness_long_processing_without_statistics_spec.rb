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

# When statistics are disabled and consumer processing takes longer than node_report_timeout,
# the node should NOT be killed because on_client_events_poll fires during wait and keeps
# liveness reporting active.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.kafka[:"statistics.interval.ms"] = 0
  config.internal.tick_interval = 1_000
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
  config.internal.swarm.node_report_timeout = 5_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe("swarm.manager.stopping") do
  DT[:killed] = true
end

class Consumer < Karafka::BaseConsumer
  def consume
    # Simulate long processing that exceeds node_report_timeout (5s)
    sleep(15)
    WRITER.puts("1")
    WRITER.flush
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(1))

started_at = nil

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets && sleep(1)
end

assert !DT.key?(:killed)

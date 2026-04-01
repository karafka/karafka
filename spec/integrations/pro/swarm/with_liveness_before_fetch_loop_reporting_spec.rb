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

# The Pro liveness listener should report healthy on before_fetch_loop so the supervisor has an
# initial healthy report before any consumption starts. This prevents the supervisor from killing
# a node whose first consumption takes longer than the report timeout.

MACOS = RUBY_PLATFORM.include?("darwin")

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  # Short report timeout so the test would fail fast without the before_fetch_loop report
  config.internal.swarm.node_report_timeout = MACOS ? 5_000 : 3_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new
)

class Consumer < Karafka::BaseConsumer
  def consume
    # Simulate a long first consumption that exceeds the report timeout.
    # Without the before_fetch_loop report, the supervisor would kill this node.
    unless DT.key?(:consumed)
      DT[:consumed] = true
      sleep(MACOS ? 4 : 2)
    end

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

stoppings = []
Karafka::App.monitor.subscribe("swarm.manager.stopping") do |event|
  stoppings << event[:status]
end

produce_many(DT.topic, DT.uuids(10))

done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 1
end

# Node should not have been stopped by the supervisor - it survived thanks to the
# before_fetch_loop report
assert_equal [], stoppings

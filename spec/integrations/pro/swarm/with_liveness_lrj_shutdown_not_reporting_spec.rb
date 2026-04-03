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

# When a node with an active LRJ enters wait_pinging (during shutdown), the events_poller
# should continue firing so the liveness listener keeps reporting to the supervisor.
# Without this fix, the supervisor considers the node non-reporting and stops it.
#
# This test sends TERM directly to the node (not the supervisor) so the supervisor's control
# loop continues monitoring while the node is in wait_pinging. If the node stops reporting,
# the supervisor issues a stop with NOT_REPORTING_SHUTDOWN_STATUS (-1).
# We assert this does not happen.

MACOS = RUBY_PLATFORM.include?("darwin")

setup_karafka(allow_errors: true) do |config|
  config.swarm.nodes = 1
  config.shutdown_timeout = 30_000
  config.internal.tick_interval = 1_000
  # Don't restart the node during the test
  config.internal.swarm.node_restart_timeout = 120_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
  # Short report timeout so the supervisor detects non-reporting quickly
  config.internal.swarm.node_report_timeout = MACOS ? 8_000 : 5_000
end

STARTED_R, STARTED_W = IO.pipe

# The Pro liveness listener hooks into client.events_poll for health reporting.
# Subscribed before fork so the child process inherits it.
Karafka.monitor.subscribe(Karafka::Pro::Swarm::LivenessListener.new)

# Extend shutdown timeout in the child so LRJ has time to finish
Karafka::App.monitor.subscribe("swarm.node.after_fork") do
  Karafka::App.config.shutdown_timeout = 30_000
end

# Track supervisor-side stopping events (status -1 = not reporting)
not_reporting_stops = []
Karafka::App.monitor.subscribe("swarm.manager.stopping") do |event|
  not_reporting_stops << event[:status] if event[:status] == -1
end

class Consumer < Karafka::BaseConsumer
  def consume
    STARTED_W.puts("1")
    STARTED_W.flush
    sleep(20)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(1))

node_termed = false

start_karafka_and_wait_until(mode: :swarm) do
  unless node_termed
    next false unless STARTED_R.wait_readable(0.1)
    STARTED_R.gets

    # Let the node establish its reporting baseline
    sleep(2)

    # Send TERM directly to the node so it enters wait_pinging while
    # the supervisor continues monitoring via manager.control
    nodes = Karafka::App.config.internal.swarm.manager.nodes
    Process.kill("TERM", nodes.first.pid)
    node_termed = true
    next false
  end

  # Wait long enough for node_report_timeout to expire if the node wasn't reporting.
  # If the fix is missing, stop_if_not_reporting fires during this window.
  sleep(MACOS ? 12 : 8)
  true
end

assert(
  not_reporting_stops.empty?,
  "Node was stopped for not reporting (status -1) during wait_pinging. " \
  "Expected events_poller.call in wait_pinging to keep the node reporting."
)

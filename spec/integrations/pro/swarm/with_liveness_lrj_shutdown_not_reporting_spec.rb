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

# When a node with an active LRJ job enters the shutdown phase, the listener exits the
# `while running?` loop and enters `wait_pinging`. Previously `wait_pinging` did not fire any
# instrumentation events (no `connection.listener.fetch_loop`, no `client.events_poll`), so the
# Pro liveness listener's `report_status` was never called and the node went silent.
#
# This test verifies that the liveness listener continues to report during the `wait_pinging`
# phase so the node does not stop communicating its health status to the supervisor.

MACOS = RUBY_PLATFORM.include?("darwin")

setup_karafka(allow_errors: true) do |config|
  config.swarm.nodes = 1
  config.shutdown_timeout = MACOS ? 20_000 : 15_000
  # Lower tick_interval so events_poller fires every 1s instead of 5s default.
  # This gives more liveness reports during the wait_pinging window.
  config.internal.tick_interval = 1_000
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
  config.internal.swarm.node_report_timeout = MACOS ? 25_000 : 20_000
end

STARTED_R, STARTED_W = IO.pipe
LIVENESS_R, LIVENESS_W = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new
)

# Subscribe inside after_fork so the callback is definitely registered in the child process.
# Track client.events_poll firing during shutdown. After the node receives TERM, done? becomes
# true. We wait a few seconds to ensure the listener has exited the fetch loop and entered
# wait_pinging, then signal via pipe.
Karafka::App.monitor.subscribe("swarm.node.after_fork") do
  Karafka::App.config.shutdown_timeout = 30_000

  poll_start = nil

  Karafka.monitor.subscribe("client.events_poll") do |_event|
    next unless Karafka::App.done?

    poll_start ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - poll_start

    # After a delay we are past the running->quieting transition and into wait_pinging
    next unless elapsed > (MACOS ? 4.0 : 3.0)

    begin
      LIVENESS_W.puts("1")
      LIVENESS_W.flush
    rescue IOError, Errno::EPIPE
      nil
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    STARTED_W.puts("1")
    STARTED_W.flush

    # Simulate a long-running job. During shutdown, the listener enters wait_pinging while
    # this job continues sleeping in the worker thread.
    sleep(30)
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

start_karafka_and_wait_until(mode: :swarm) do
  STARTED_R.gets
end

# Collect any liveness reports written during the wait_pinging phase
LIVENESS_W.close
shutdown_reports = []
while (line = LIVENESS_R.gets)
  shutdown_reports << line.strip
end
LIVENESS_R.close

assert(
  shutdown_reports.size >= 1,
  "Expected liveness reports during wait_pinging but got none. " \
  "wait_pinging does not fire events for the liveness listener to hook into."
)

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

# Comprehensive pipe FD stability test under realistic swarm workload.
# Runs 2 nodes with multiplexing, consumer-side producing, and periodic node restarts.
# Asserts that pipe FD count in the supervisor does not grow over time — catching leaks
# from any source (node management, librdkafka, WaterDrop, etc.).

setup_karafka do |config|
  config.swarm.nodes = 2
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      # Produce back to exercise WaterDrop producer pipes in forked process
      produce_sync(topic: DT.topics[1], payload: message.raw_payload)
    end

    WRITER.puts("1")
    WRITER.flush

    @consume_count ||= 0
    @consume_count += 1

    # Trigger node restart every 3rd consume call to exercise the fork cycle
    exit! if (@consume_count % 3).zero?
  end
end

draw_routes do
  subscription_group do
    multiplexing(max: 2, min: 1, boot: 2)

    topic DT.topics[0] do
      consumer Consumer
      config(partitions: 4)
    end

    topic DT.topics[1] do
      consumer Consumer
      config(partitions: 4)
    end
  end
end

def count_pipe_fds
  Dir.glob("/proc/self/fd/*").count do |fd_path|
    File.readlink(fd_path).start_with?("pipe:")
  rescue Errno::ENOENT
    false
  end
end

# Sample pipe FD count in the supervisor after every fork
Karafka::App.monitor.subscribe("swarm.manager.after_fork") do
  DT[:pipe_counts] << count_pipe_fds
end

# Produce enough messages to sustain consumption for ~60s across restarts
4.times do |i|
  produce_many(DT.topics[0], DT.uuids(100), partition: i)
end

START_TIME = Process.clock_gettime(Process::CLOCK_MONOTONIC)

start_karafka_and_wait_until(mode: :swarm) do
  READER.gets
  # Run for at least 60 seconds to catch slow leaks (e.g. every 10s)
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - START_TIME >= 60
end

pipe_counts = DT[:pipe_counts]

# On Linux we expect meaningful pipe FD samples from the supervisor
# On non-Linux, count_pipe_fds returns 0 (no /proc/self/fd), so the assertion trivially passes
if pipe_counts.size >= 2
  growth = pipe_counts.last - pipe_counts.first
  assert growth <= 4, "Pipe FDs grew by #{growth} (#{pipe_counts.first} -> #{pipe_counts.last}), indicating a leak"
end

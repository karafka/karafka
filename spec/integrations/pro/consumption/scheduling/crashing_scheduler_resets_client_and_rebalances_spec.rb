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

# Illustrates the danger documented in the Scheduling API wiki: a custom scheduler runs in the
# listener (polling) thread, so an unhandled error in it is a CRITICAL failure. Karafka recovers
# the only way it can at that level - by resetting the underlying client for the subscription
# group - and a client reset makes the process leave and rejoin the consumer group, i.e. it
# triggers a rebalance.
#
# Here the scheduler crashes once on its first consumption scheduling. We assert that the crash:
#   * surfaced as a listener fetch-loop error,
#   * caused a client reset,
#   * triggered a rebalance (a second assignment beyond the initial join),
# and that Karafka then recovered and consumed every message.
#
# This is exactly why a persistent scheduler bug causes a rebalance storm - and why custom
# schedulers must never let exceptions escape.

become_pro!

# Default scheduler that raises the first time it is asked to schedule consumption jobs, then
# behaves exactly like the stock scheduler afterwards (so the system can recover).
class CrashOnceScheduler < Karafka::Pro::Processing::Schedulers::Default
  def on_schedule_consumption(jobs_array)
    return super if @crashed

    @crashed = true
    DT[:crashes] << true

    raise StandardError, "intentional scheduler crash to illustrate the reset/rebalance"
  end
end

setup_karafka(allow_errors: true) do |config|
  config.internal.processing.scheduler_class = CrashOnceScheduler
  config.max_messages = 100
end

# The crash bubbles to the listener fetch-loop catch-all as this error type
Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:fetch_loop_errors] << true if event[:type] == "connection.listener.fetch_loop.error"
end

# Fires only when Karafka resets the underlying client (never on a normal join/shutdown)
Karafka.monitor.subscribe("client.reset") do |_event|
  DT[:client_resets] << true
end

# Initial join fires one assignment; the reset-driven rejoin fires another -> proves the rebalance
Karafka.monitor.subscribe("rebalance.partitions_assigned") do |_event|
  DT[:assignments] << true
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.raw_payload }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:consumed].uniq.size >= 20
end

# The scheduler crashed exactly once
assert_equal 1, DT[:crashes].size
# ...surfaced as a listener fetch-loop error
assert DT[:fetch_loop_errors].any?
# ...which Karafka recovered from by resetting the client
assert DT[:client_resets].any?
# ...and that reset rejoined the group - a rebalance (initial assignment + the post-reset one)
assert DT[:assignments].size >= 2
# ...and despite all that, every message was eventually consumed
assert_equal 20, DT[:consumed].uniq.size

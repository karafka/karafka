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

# The recurring tasks schedule snapshot persists each task's `previous_time` after it runs. It must
# be dispatched synchronously, so the `previous_time` update is durably stored before the executor
# proceeds. With an async dispatch, a crash after a task executed but before the snapshot was
# delivered would lose the update and re-run the task on the next replay (double execution).
#
# Reproducing the actual crash window requires an ungraceful kill (a graceful shutdown flushes the
# async buffer), so instead we assert the durability guarantee directly via WaterDrop's own
# produced-sync/produced-async instrumentation: the schedule snapshot must go out synchronously.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

schedules_topic = Karafka::App.config.recurring_tasks.topics.schedules.name
producer = Karafka::App.config.recurring_tasks.producer

producer.monitor.subscribe("message.produced_sync") do |event|
  message = event[:message]
  DT[:sync] << message[:key] if message[:topic] == schedules_topic
end

producer.monitor.subscribe("message.produced_async") do |event|
  message = event[:message]
  DT[:async] << message[:key] if message[:topic] == schedules_topic
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "task", cron: "* * * * *", previous_time: Time.now - 600_000) do
    DT[:executions] << Time.now.to_f
  end
end

start_karafka_and_wait_until(reset_status: true) do
  # Wait until the task ran and a schedule snapshot was dispatched (whichever way it went out)
  DT[:executions].size >= 1 && (DT[:sync] + DT[:async]).include?("state:schedule")
end

# The schedule snapshot (which persists previous_time) must be dispatched synchronously
assert(
  DT[:sync].include?("state:schedule"),
  "schedule snapshot was not dispatched synchronously (sync=#{DT[:sync]}, async=#{DT[:async]})"
)

assert(
  !DT[:async].include?("state:schedule"),
  "schedule snapshot was dispatched asynchronously: #{DT[:async]}"
)

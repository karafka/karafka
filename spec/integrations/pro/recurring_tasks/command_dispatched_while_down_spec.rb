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

# A command dispatched while the recurring tasks consumer is down is consumed during the replay
# phase of the next start. Its effect must survive the end-of-replay synchronization with the
# last stored schedule snapshot and must be reflected in the persisted post-replay state.
#
# A task disabled while the process was down must come up disabled. Prior to the fix, the replay
# applied the command and then reverted it from the snapshot (the catchup commands buffer was
# never populated), persisting the reverted state and losing the command permanently.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "task", cron: "* * * * *", previous_time: Time.now - 600_000) do
    DT[:executions] << Time.now.to_f
  end
end

schedules_topic = Karafka::App.config.recurring_tasks.topics.schedules.name

# Run 1: the enabled task executes and snapshots of the enabled state are persisted
start_karafka_and_wait_until(reset_status: true) do
  DT[:executions].size >= 1
end

# Re-setup so we get a fresh producer (the previous one was closed on shutdown)
setup_karafka

before_command = Karafka::Admin.read_watermark_offsets(schedules_topic, 0).last

# While the consumer is down, request disabling of the task. The command will be read during
# the replay phase of the next start.
Karafka::Pro::RecurringTasks.disable("task")

# Make sure the command reached Kafka before we boot again, so it is part of the replay and not
# consumed live after the replay has finished
100.times do
  break if Karafka::Admin.read_watermark_offsets(schedules_topic, 0).last > before_command

  sleep(0.2)
end

before_replay = Karafka::Admin.read_watermark_offsets(schedules_topic, 0).last

# Run 2: replay processes the stored snapshots (enabled) and the disable command. We wait until
# the end-of-replay snapshot is persisted.
start_karafka_and_wait_until do
  Karafka::Admin.read_watermark_offsets(schedules_topic, 0).last > before_replay
end

task = Karafka::Pro::RecurringTasks.schedule.find("task")

assert_equal(
  false,
  task.enabled?,
  "disable command consumed during replay was reverted by the snapshot synchronization"
)

# The post-replay snapshot persisted to Kafka must also reflect the disabled state, otherwise
# the command is lost permanently (subsequent restarts replay from this wrong snapshot)
last_state = Karafka::Admin
  .read_topic(schedules_topic, 0, 5)
  .reverse.find { |message| message.payload[:type] == "schedule" }

assert_equal(
  false,
  last_state.payload[:tasks][:task][:enabled],
  "post-replay snapshot persisted the reverted (enabled) state, losing the command permanently"
)

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

# When commands keep arriving right after the schedules topic reaches its end during the replay,
# its EOF and the commands after it can come in one drain. The EOF is then cleared, but the replay
# should still finish on a later EOF and the tasks should run.

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

# A backlog keeps the consumer busy while the end of the topic and new commands after it queue up
20_000.times { Karafka::Pro::RecurringTasks.enable("task") }

# Bursts with gaps let librdkafka reach the end of the topic between them, so new commands queue
# up behind its EOF
Thread.new do
  sleep(0.1) until Karafka::App.running?

  deadline = Time.now + 10

  while Time.now < deadline
    50.times { Karafka::Pro::RecurringTasks.enable("task") }

    sleep(0.5)
  end
end

start_karafka_and_wait_until do
  DT[:executions].size >= 1
end

assert Karafka::Pro::RecurringTasks.schedule.find("task").enabled?

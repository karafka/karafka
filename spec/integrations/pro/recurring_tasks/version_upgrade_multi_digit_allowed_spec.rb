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

# A recurring-tasks schedule upgrade must be allowed even when version segments are multi-digit.
# The catch-up replay compared the stored schedule version against the current one to reject
# downgrades; comparing them as plain strings ordered multi-segment versions lexicographically, so
# `"1.9.0" > "1.10.0"` was true and a valid 1.9.0 -> 1.10.0 upgrade was wrongly rejected as
# incompatible (raising `IncompatibleScheduleError` and blocking all task execution). With the
# `Gem::Version` comparison the upgrade is recognised as newer and proceeds.

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.9.0") do
  schedule(id: "run", cron: "* * * * *", previous_time: Time.now - 600_000) do
    DT[:done] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger("run")
    @dispatched = true
  end

  DT.key?(:done)
end

# Second boot: a higher (multi-digit) version. This is an upgrade and must be accepted.
setup_karafka(allow_errors: %w[consumer.consume.error])

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error] if event[:type] == "consumer.consume.error"
end

Karafka::Pro::RecurringTasks.define("1.10.0") do
  schedule(id: "run", cron: "* * * * *") do
    DT[:done2] = true
  end
end

start_karafka_and_wait_until(reset_status: true) do
  unless @dispatched2
    sleep(2)
    Karafka::Pro::RecurringTasks.trigger("run")
    @dispatched2 = true
  end

  DT.key?(:done2) ||
    DT[:errors].any? { |error| error.is_a?(Karafka::Pro::RecurringTasks::Errors::IncompatibleScheduleError) }
end

# 1.10.0 is newer than the stored 1.9.0, so the schedule must not be treated as incompatible.
assert(
  DT[:errors].none? { |error| error.is_a?(Karafka::Pro::RecurringTasks::Errors::IncompatibleScheduleError) },
  "1.9.0 -> 1.10.0 upgrade was wrongly rejected as incompatible"
)

assert DT.key?(:done2), "the upgraded schedule did not run"

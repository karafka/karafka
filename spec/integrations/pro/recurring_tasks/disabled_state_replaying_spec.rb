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

# When we have an active schedule that got disabled, after a re-run we should be able to
# recover its inactive state

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  # This should never run. Alongside of this case, we also check that the command matching
  # works correctly and does not trigger this one
  schedule(id: "crash", cron: "* * * * *", previous_time: Time.now - 600_000) do
    if DT.key?(:rerun)
      raise
    else
      DT[:run] = true
    end
  end
end

start_karafka_and_wait_until(reset_status: true) do
  if DT.key?(:run)
    Karafka::Pro::RecurringTasks.disable("crash")
    sleep(1)
    DT[:done] = true
  end

  DT.key?(:done)
end

DT[:rerun] = true

setup_karafka

start_karafka_and_wait_until do
  sleep(5)
end

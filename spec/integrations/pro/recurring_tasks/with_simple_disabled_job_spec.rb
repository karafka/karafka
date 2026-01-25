# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Disabled job should not run even when manually triggered

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

Karafka::Pro::RecurringTasks.define("1.0.0") do
  # This one should trigger only once during the explicit trigger request
  schedule(id: "stop", cron: "* * * * *", enabled: false) do
    DT[:disabled_done] << true
  end

  # This should never run. Alongside of this case, we also check that the command matching
  # works correctly and does not trigger this one
  schedule(id: "crash", cron: "* * * * *", enabled: false) do
    raise
  end

  # This one will trigger fast because we set previous time in the past
  schedule(id: "trigger", cron: "* * * * *", previous_time: Time.now - 120_000) do
    DT[:active_done] = true
  end
end

start_karafka_and_wait_until do
  if DT.key?(:active_done) && !@dispatched
    Karafka::Pro::RecurringTasks.trigger("stop")
    @dispatched = true

    true
  end

  DT.key?(:disabled_done)
end

assert_equal 1, DT[:disabled_done].size

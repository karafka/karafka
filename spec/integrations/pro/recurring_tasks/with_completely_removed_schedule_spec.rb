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

# We should be able to remove all the tasks and it should not trigger them ever

setup_karafka

draw_routes do
  recurring_tasks(true) do
    max_wait_time 500
  end
end

future_date = Time.now + (7 * 24 * 60 * 60) # 7 days in seconds
FUTURE_CRON = "0 12 #{future_date.day} #{future_date.month} *".freeze

Karafka::Pro::RecurringTasks.define("1.0.0") do
  schedule(id: "a", cron: FUTURE_CRON, enabled: false) do
    raise
  end

  schedule(id: "b", cron: FUTURE_CRON, enabled: false) do
    raise
  end

  schedule(id: "c", cron: FUTURE_CRON, previous_time: Time.now - 120_000) do
    raise
  end
end

start_karafka_and_wait_until do
  sleep(10)
end

setup_karafka

# This will simulate removing whole schedule
Karafka::Pro::RecurringTasks.define("1.0.0") { nil }

start_karafka_and_wait_until do
  unless @dispatched
    Karafka::Pro::RecurringTasks.trigger("*")
    @dispatched = true
    sleep(5)
  end

  true
end
